{-# LANGUAGE DataKinds             #-}
{-# LANGUAGE DeriveAnyClass        #-}
{-# LANGUAGE DeriveGeneric         #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE PartialTypeSignatures #-}
{-# LANGUAGE QuasiQuotes           #-}
{-# LANGUAGE ScopedTypeVariables   #-}
module Main where
import           Control.Concurrent                  ()
import           Control.Concurrent.Async            ()
import           Control.Concurrent.ParallelIO.Local (parallelInterleavedE,
                                                      withPool)
import           Control.Concurrent.Thread.Delay     (delay)
import           Control.Monad                       (when)
import           Data.Aeson                          as J
import           Data.Aeson.Types                    as J
import qualified Data.ByteString                     as BS
import qualified Data.ByteString.Lazy                as BSL
import           Data.Char                           (toUpper)
import           Data.Default                        (def)
import           Data.List
import           Data.Monoid                         ((<>))
import qualified Data.Yaml                           as Y
import qualified GHC.IO.BufferedIO                   as IO
import qualified GHC.IO.Handle                       as IO
import qualified GHC.IO.Handle.Types                 as IO
import           System.Directory                    (createDirectoryIfMissing,
                                                      doesFileExist,
                                                      findExecutable)
import           System.Exit                         (ExitCode (..), exitWith)
import           System.IO                           (IOMode (..), withFile)
import           System.IO.Temp                      (withSystemTempDirectory)
import qualified System.Posix.IO                     as IO
import           System.Process                      (CmdSpec (RawCommand),
                                                      CreateProcess,
                                                      StdStream (..),
                                                      callProcess)
import qualified System.Process                      as P
--import           Data.Semigroup                      ((<>))
import           Data.Text                           (Text, toLower)
import qualified Data.Text                           as T
import           GHC.Generics
import           Options.Applicative                 as A
import           System.Console.AsciiProgress        (Options (..),
                                                      RegionLayout (Linear),
                                                      def,
                                                      displayConsoleRegions,
                                                      isComplete,
                                                      newProgressBar, tick,
                                                      withConsoleRegion)
import           System.Console.Concurrent           ()
import           System.Console.Regions              ()
import           System.Environment                  (getArgs, getEnvironment,
                                                      lookupEnv)
import           System.Random

xc_infra_api_version = "1"
-- TODO: make sure name is restricted to dns names
-- TODO: add XC_INTERACTIVE var to change interactive mode (ask questions to user before any action) (or terminal tty detection)
-- TODO: || is used as data separator in backend

data DeployOptions = DeployOptions { de_infra                :: !(Maybe String),
                                     de_name                 :: !(Maybe String),
                                     de_nix_path             :: !(Maybe String),
                                     de_nodes                :: !(Maybe Int),
                                     de_ssh_private_key_path :: !(Maybe String)}
  deriving (Eq, Show)

data StopOptions = StopOptions { st_infra :: !String,
                                 st_name  :: !String}
  deriving (Eq, Show)

data StdOptions = StdOptions { std_infra :: !String,
                               std_name  :: !String}
  deriving (Eq, Show)

data NodeOptions = NodeOptions { nd_infra         :: !String,
                                 nd_name          :: !String,
                                 nd_node_selector :: !String}
  deriving (Eq, Show)

data Command
  = Deploy (DeployOptions)
  | Stop (Maybe StopOptions)
  | Destroy (Maybe StopOptions)
  | Verify
  | Build
  | CopyTo
  | CopyFrom
  | CopyNixClosureTo
  | CopyNixClosureFrom
  | Nodes (Maybe StdOptions)
  | IPs (Maybe StdOptions)
  | IP (Maybe NodeOptions)
  | SSH (Maybe NodeOptions)
  | ImplementInfra
  | TestInfraImplementation
  | DumpNixOSHardware
  | DumpConfig
  deriving (Show, Generic, Eq)


-- TODO: allow multiple ssh keys

deploy_parser :: A.Parser DeployOptions
deploy_parser =  (DeployOptions <$> optional (option str (long "infra" <> short 'i' <> metavar "PATH" <> help "Backend can be name (one of available backends 'list-infra' or a path to executable"  <> showDefault))
                                <*> optional (option str (long "name" <> short 'n' <> metavar "NAME" <> help "Just a token passed to backend, backend may locate cluster based on that value"  <> showDefault))
                                <*> optional (option str (long "ssh-private-key-path" <> short 's' <> metavar "PATH" <> help "Path to ssh private key"  <> showDefault))
                                <*> optional (option auto (long "nodes-count" <> short 'c' <> metavar "NUM" <> help "Number of nodes in the cluster" <> showDefault))
                                <*> optional (option str (long "nix-expression" <> short 'x' <> metavar "PATH" <> help "Path to nix expression which generates machines configurations"))
                )

stop_parser =  (StopOptions <$> (option str (long "infra" <> short 'i' <> metavar "INFRA" <> help "Backend can be name (one of available backends 'list-infra' or a path to executable"  <> showDefault))
                            <*> (option str (long "name" <> short 'n' <> metavar "NAME" <> help "Just a token passed to backend, backend may locate cluster based on that value"  <> showDefault))
                )
std_parser =  (StdOptions <$> (option str (long "infra" <> short 'i' <> metavar "INFRA" <> help "Backend can be name (one of available backends 'list-infra' or a path to executable"  <> showDefault))
                            <*> (option str (long "name" <> short 'n' <> metavar "NAME" <> help "Just a token passed to backend, backend may locate cluster based on that value"  <> showDefault))
                )


commands :: A.Parser Command
commands = hsubparser
       (
        commandGroup "NixOS Cluster operations:"
  --      command "create" (info (Create <$> create_parser) (progDesc "Print greeting"))
     <> command "deploy" (info (Deploy <$> deploy_parser) (progDesc "Create new cluster or reshape existing one and deploy NixOS Cluster"))
     <> command "stop" (info (Stop <$> optional stop_parser) (progDesc "bla"))
     <> command "destroy" (info (Destroy <$> optional stop_parser) (progDesc "bla"))
       )
      <|> hsubparser
       (
       commandGroup "Interactive NixOS Cluster commands (usually work based on node selectors):"
       <> command "activate" (info (Nodes <$> optional std_parser) (progDesc "List all node IDs"))
       <> command "nodes" (info (Nodes <$> optional std_parser) (progDesc "List all node IDs"))
       <> command "ips" (info (IPs <$> optional std_parser) (progDesc "Prints list of nodes names and their private ip (used to inter-node communication)"))
       <> command "ip" (info (IPs <$> optional std_parser) (progDesc "PRint node private ip only (used to inter-node communication)"))
       <> command "ssh" (info (IPs <$> optional std_parser) (progDesc "PRint node private ip only (used to inter-node communication)"))
       <> command "reboot" (info (IPs <$> optional std_parser) (progDesc "PRint node private ip only (used to inter-node communication)"))
       <> command "mount" (info (IPs <$> optional std_parser) (progDesc "PRint node private ip only (used to inter-node communication)"))
       <> command "unmount" (info (IPs <$> optional std_parser) (progDesc "PRint node private ip only (used to inter-node communication)"))
       <> command "verify" (info (pure Verify) (progDesc "Verifies backend configuration."))
       <> hidden
       )
      <|> hsubparser
       (
       commandGroup "Low level NixOS Cluster commands:"
       <> command "fetch-nixos-hardware" (info (pure Build) (progDesc "Fetch NixOS hardware description from infrastructure"))
       <> command "build" (info (pure Build) (progDesc "fetch-nixos-hardware + build with NixOS Cluster deployment"))
       <> command "copy-to" (info (pure CopyTo) (progDesc ""))
       <> command "copy-from" (info (pure CopyFrom) (progDesc ""))
       <> command "copy-nix-closure-to" (info (pure CopyNixClosureTo) (progDesc ""))
       <> command "copy-nix-closure-from" (info (pure CopyNixClosureFrom) (progDesc ""))
       <> command "verify" (info (pure Verify) (progDesc "Verifies backend configuration."))
       <> hidden
       )
      <|> hsubparser
       (
       commandGroup "Backend writing commands:"
       <> command "implement-infra" (info (pure ImplementInfra) (progDesc "Say goodbye"))
       <> command "test-infra-implementation" (info (pure TestInfraImplementation) (progDesc "Say goodbye"))
       <> hidden
       )


ssh x = do
  i <- withConsoleRegion Linear $ \r -> do
    pg <- newProgressBar def {
      pgFormat = "Worker: "++ show x ++" :bar :percent",
      pgTotal = 20,
      pgOnCompletion = Just "DONE!"
    }
    -- appendConsoleRegion r ("start:" ++ show x)
    let go = do
          i <- getStdRandom (randomR (10000, 60000))
          tick pg
          delay $ i
          return i
    go
    go
    go
    go
    go
    go
    go
    go
    go
    go
    go
    go
    go
    go
    go
    go
    go
    go
    go
    go
    -- appendConsoleRegion r ("stop:" ++ show x)
    -- finishConsoleRegion r ("OK:" ++show x)
    return x
  return i

find_infra :: String -> IO FilePath
find_infra infra_name = do
  does_exist <- doesFileExist infra_name
  case does_exist of
    True -> do
      return infra_name
    False -> do
      p <- findExecutable ("xc-infra-" ++ infra_name)
      case p of
        Nothing -> do
            putStrLn $ "ERROR: Infra '" ++ infra_name ++ "' not found (as command in search path)! "
            putStrLn $ "ERROR: Make sure 'xc-infra-"++infra_name++"' is in PATH and it is executable"
            putStrLn $ "ERROR: You can also specify path directly to infra executable"
            exitWith (ExitFailure 30)

        Just a -> return a



infra_exec_yaml :: (FromJSON a, ToJSON a) => FilePath -> [(String, String)] -> [String] -> IO a
infra_exec_yaml infra env cmd = do
--  (fd_r, fd_w) <- IO.createPipe
--  r <- IO.fdToHandle fd_r
--  w <- IO.fdToHandle fd_w
--  IO.hSetBinaryMode r True
--  IO.hSetBuffering r IO.NoBuffering
--  IO.hSetBinaryMode w True
--  IO.hSetBuffering w IO.NoBuffering
  (exit_code, Just r, _) <- infra_exec infra env cmd True False
  contents <- BS.hGetContents r
  case Y.decodeEither contents of
    Right o -> return o
    Left b -> do
      putStrLn $ "ERROR: Error while decoding output from '"++show cmd++"' command to infra '"++infra++"'"
      putStrLn $ "ERROR: " ++ b
      putStrLn $ "--- content ----"
      putStrLn $ show $ contents
      putStrLn $ "--- /content ----"
      exitWith $ ExitFailure 35


get_nodes infra_path cluster_name = do
  ids :: [String] <- infra_exec_yaml infra_path [("XC_NAME", cluster_name)] ["nodes-ids"]
  return $ ids -- map (get_node infra_path cluster_name) ids

infra_exec :: FilePath -> [(String, String)] -> [String] -> Bool -> Bool -> IO (ExitCode, Maybe IO.Handle, Maybe IO.Handle)
infra_exec infra_path env cmd stdout stderr = do
  putStrLn $ "[DEBUG] Executing backend: " ++ (show (infra_path: cmd))
  e <- getEnvironment
  let proc = P.CreateProcess {
    P.cmdspec = P.RawCommand infra_path cmd,
    P.cwd = Nothing,
    --  TODO: XC_TOKEN could be random, so all command execution has trace, probably read monad needed
    P.env = Just (env ++ [("XC_TOKEN", "1"), ("XC_INFRA_API_VERSION", xc_infra_api_version)] ++ e),
    P.std_in = P.NoStream,
    P.std_out = case stdout of
                  True  -> P.CreatePipe
                  False -> P.Inherit,
    P.std_err = case stderr of
                  True  -> P.CreatePipe
                  False -> P.Inherit,
    P.close_fds = False,
    P.create_group = False,
    P.delegate_ctlc = False,
    P.detach_console = False,
    P.create_new_console = False,
    P.new_session = False,
    P.child_group = Nothing,
    P.child_user = Nothing
    -- P.use_process_jobs = False
  }
  (_, stdout, stderr, process) <- P.createProcess_ "WHAT IS THAT!!??" proc
  exit_code <- P.waitForProcess process
  case exit_code of
   ExitSuccess -> putStrLn $ "[DEBUG] infra command ok"
   _           -> putStrLn $ "[DEBUG] infra command failed"
  return (exit_code, stdout, stderr)

get_env_for_arg :: String -> IO String
get_env_for_arg env = do
  out <- lookupEnv env
  case out of
    Just a -> return a
    Nothing -> do
      putStrLn $ "ERROR: Environment variable " ++ env++" required but not set!"
      putStrLn $ "ERROR: XC can work in one of two modes, contextual and direct"
      putStrLn $ "ERROR: In contextual mode (current mode) it does use mostly environment variables as user input"
      putStrLn $ "ERROR: In direct mode it uses CLI --options and not environment variables"
      exitWith $ ExitFailure 32

get_arg_or_env :: String -> Maybe String -> String -> Maybe String -> IO String
get_arg_or_env arg_name arg_value env_name def = do
  out <- lookupEnv env_name
  case arg_value of
    Just v -> return v
    Nothing -> do
      (case out of
        Just a -> return a
        Nothing -> do
            (case def of
              Just a -> return a
              Nothing -> do
                putStrLn $ "ERROR: Environment variable " ++ env_name ++" required but not set!"
                putStrLn $ "ERROR: XC can work in one of two modes, contextual and direct"
                putStrLn $ "ERROR: In contextual mode (current mode) it does use mostly environment variables as user input"
                putStrLn $ "ERROR: In direct mode it uses CLI --options and not environment variables"
                exitWith $ ExitFailure 32
                )
        )

withBuildPath func = do
  out <- lookupEnv "XC_DEBUG_BUILD_PATH"
  case out of
    Nothing -> withSystemTempDirectory "xc" func
    Just o  -> do
      createDirectoryIfMissing True o
      (func o)

data Node = Node {
  n_id :: !String
} deriving (Generic, Show)
instance ToJSON Node
instance FromJSON Node

get_node infra_path node_id = do
  return ()



run (Deploy a) = do
  infra_path <- get_arg_or_env "--infra" (de_infra a) "XC_INFRA" Nothing
  i <- find_infra (infra_path)
  cluster_name <- get_arg_or_env "--name" (de_name a) "XC_NAME" Nothing
  let n = case de_nodes a of
            Just v  -> Just (show v)
            Nothing -> Nothing
  nodes_count <- get_arg_or_env "--nodes-count" (n) "XC_NODES_COUNT" (Just (""))
  ssh_key <- get_arg_or_env "--ssh-private-key-path" (de_ssh_private_key_path a) "XC_SSH_PRIVATE_KEY_PATH" Nothing
  nix_expr <- get_arg_or_env "--nix-expression" (de_nix_path a) "XC_NIX_EXPRESSION" (Just "./xc.nix")
  does_it <- doesFileExist nix_expr
  case does_it of
    False -> do
      putStrLn $ "ERROR: File with nix expression '"++nix_expr++"' (set by --nix-expression or XC_NIX_EXPRESSION) does not exist!"
      exitWith $ ExitFailure 33
    True -> do
        infra_exec i
             [("XC_NAME", cluster_name),
              ("XC_NODES_COUNT", nodes_count),
              ("XC_SSH_PRIVATE_KEY_PATH", ssh_key)]
             ["shape"] False False
        withBuildPath $ \bpath -> do
          withFile (bpath ++ "/xc-test1-node0.hardware.nix") WriteMode $ \h -> do
            (exit_code, _, _) <- infra_exec i
                                   [("XC_NAME", cluster_name),
                                    ("XC_NODE_ID", "xc-test1-node-0"),
                                    ("XC_SSH_PRIVATE_KEY_PATH", ssh_key)]
                                   ["node-hardware-nix"] True False
            return ()
          nodes :: [String] <- get_nodes i cluster_name
          putStrLn $ show nodes
          return ()
run (Stop (Just a)) = do
  i <- find_infra (st_infra a)
  infra_exec i [("XC_NAME", st_name a)] ["stop"] False False
  return ()
run (Stop Nothing) = do
  infra <- get_env_for_arg "XC_INFRA"
  i <- find_infra (infra)
  name <- get_env_for_arg "XC_NAME"
  infra_exec i [("XC_NAME", name)] ["stop"] False False
  return ()
run (Nodes (Just a)) = do
  i <- find_infra (std_infra a)
  return ()
run (Nodes Nothing) = do
  infra <- get_env_for_arg "XC_INFRA"
  i <- find_infra (infra)
  name <- get_env_for_arg "XC_NAME"
  return ()
run (Destroy (Just a)) = do
  i <- find_infra (st_infra a)
  infra_exec i [("XC_NAME", st_name a)] ["destroy"] False False
  return ()
run (Destroy Nothing) = do
  infra <- get_env_for_arg "XC_INFRA"
  i <- find_infra (infra)
  name <- get_env_for_arg "XC_NAME"
  infra_exec i [("XC_NAME", name)] ["destroy"] False False
  return ()
--  displayConsoleRegions $ do
--    withPool 10 $ \pool -> do
--      out <- parallelInterleavedE pool [ssh i | i <- [1..100]]
--      return ()



main = do
  let prefs = A.prefs (A.showHelpOnEmpty <> A.showHelpOnError)
  args <- A.customExecParser prefs (info (commands <**> A.helper) (header "bo" <> footer "OKOK" <> progDesc "desc"))
  run args
  return ()


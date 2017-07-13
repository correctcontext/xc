XC - NixOS Cluster
==================

XC (NixOS Cluster) is a pattern and reference implementation for cluster/cloud
manager based on `libbashuu`. Created for and thought around NixOS in mind, but
can be used in wider scope.

Principles
----------

1. Infrastructure is THE STATE
   - no local state that mirrors real world (which is always behind the actual world)
   - no any other state anywhere else
   - just use your infrastructure, really, you will avoid so many suprises
   - nope, yaml and json files also cannot keep your state
2. Idempotency
   - manage the desired state, not transitions
   - transitions are just your way to get there
   - all high level `commands` **should be** idempotent
   - low level/`plumbing commands` **could be** imperative, but try to not overuse that
3. Easiness + Simplicity (easy to write, maintain, use)
   - they say simple is not easy
   - but let's try to go closer, set right boundaries
   - **easy** CLI `commands` for day to day usage (complexity hidden behind CLI library)
   - **simple** `plumbing commands` implementations 
   - make simple and easy infrastructure code, move complexity into CLI library which is far away (but not further than needed) from you and put focus on important stuff
   - instead of figuring out 5 new languages (the problem is not to learn them, problem is to debug them and be efficient with them) use just bash, the tool you know very well already (or maybe you don't, but if you doing some ops, probably you want to learn it anyway)


Why
---

TLDR; write your own tools, that's better then working around other tools' limitations.

  I spent 
  too much time using specific solutions, 
  too much time reading unupdated documentation, 
  too much time debugging issues in that software,
  too much time working around those issues,
  too much time working around specific design choices,
  too much time working around limitations.
  I know my code, its limitations. It perfectly fits its use cases.
  Just give me the easier way to take care writing infra code.

Framework issue - when using frameworks or out of the box solutions you can
usually start easily. The cost is, as your infrastructure grows and you want to
implement more and more specific solutions that are not present in current
solution, it's harder and harder to maintain both infrastructure and code.
Usually this leads to producing workarounds because tool limitations rather
than actual problem solving.

`NixOS Cluster` is a way to address that problem.  Instead of giving you a tool
which soon will be your limitation and nightmare that you are fighting against,
it is a library and set of rules to follow so you can evolve your
infrastructure as a code.

How to use it?
--------------

You have this environment:
- production deployment on cloud service (AWS or other thing like that)
- local development for Linux users (KVM)
- local development for other folks (VirtualBox)
- local environments don't have to be the same, they are just to make sure
  developers can feel some network scenarios
- project is called "foo-foo" so we use `ff` shortcut

Your potential solution:
- production deployment
  - let's build the thing before deployment
  - make sure the new boxes are up and running
  - make sure load balancers are up and running
  - deploy code to new boxes
  - do some internal checks
  - switch load balancers
  - tear down old boxes
- local environment
  - make sure local box is running as fast as it can
  - make sure code is pushed as fast as it can (we may even have completely different pipeline for deploying that code)

How to to that with `xc`?

- write your desired `command` usage patterns (documentation and tests first, lol):

    **Your day to day interaction**

    `commands`
    - `ff deploy --number-of-servers X --number-of-loadbalancers Y`
    - `ff destroy` - should work only locally
    - `ff state` - deploy ascii table with info I need

    - `ff deploy-loadbalancers --number-of-loadbalancers Y`
    - `ff deploy-boxes --number-of-servers X`

    `plumbing commands` – those can be used by commands above under the hood
    - `ff create-my-specific-load-balancer`
    - `ff destroy-my-specific-load-balancer`
    - `ff switch-load-balancers-to-new-deployment-and-wait-30-seconds-and-rollback-on-error`
- let's make a decision, that we want to have two separate command sets for local and production deployments (with one interface).

    `ff-local`
    ```bash
    #!/usr/bin/env bash
    set -euo pipefail
    export SHELLOPTS
    HERE=$(readlink -f "$(dirname "${BASH_SOURCE[0]}")")
    export "PATH=$PATH:$HERE/virsh-implementation"
    # set some implementation specific variables
    export VIRSH_DEFAULT_CONNECT_URI=qemu:///system
    export MY_VIRSH_PREFIX=ff-
    # set some defaults if user does not specify any
    export NUMBER_OF_SERVERS=1
    export NUMBER_OF_LOAD_BALANCERS=0
    exec ff "$@"  # we will use the same interface, just `ff` command will discover implementations in different PATH
    ```

    `ff-prod`
    ```bash
    #!/usr/bin/env bash
    set -euo pipefail
    export SHELLOPTS
    HERE=$(readlink -f "$(dirname "${BASH_SOURCE[0]}")")
    export "PATH=$PATH:$HERE/aws-implementation"
    # set some implementation specific variables
    export AWS_DEFAULT_PROFILE=ff
    export S3_DEPLOYMENT_BUCKET=s3://my-deployments/
    # set some defaults if user does not specify any
    export NUMBER_OF_SERVERS=10
    export NUMBER_OF_LOAD_BALANCERS=2
    exec ff "$@"
    ```

    That way we have two identical (parametrized) interfaces to interact with,
    but two different implementations (aka strategy pattern).

- write `command` declarations:

    `ff-destroy` – this `command` will be executed by both entrypoints: `ff-prod` and `ff-local`
    ```bash
    #!/usr/bin/env bash
    set -euo pipefail
    export SHELLOPTS
    HERE=$(dirname "${BASH_SOURCE[0]}")
    source libbashuu

    uu::command::set-description "Destroy infrastructure"
    uu::command::set-scope cluster
    uu::command::require-implementation ff-destroy-implementation
    uu::command::main "$@"

    source ff-destroy-implementation
    ```

- write two implementations of those `commands`, in bash

    `/virsh-implementation/ff-destroy-implementation`
    ```bash
    # put your specific implementation logic here
    virsh destroy ${MY_VIRSH_PREFIX}local
    virsh net-destroy ${MY_VIRSH_PREFIX}local
    ```

    `/aws-implementation/ff-destroy-implementation`
    ```bash
    uu::error "This is not implemented by purpose"
    uu::error "Are you drunk? Go to sleep."
    exit 1
    ```

    `/virsh-implementation/ff-state-implementation`
    ```bash
    virsh list | grep ${MY_VIRSH_PREFIX}
    virsh net-list |grep ${MY_VIRSH_PREFIX}
    virsh domifaddr | grep $(virsh list --name | egrep "^${MY_VIRSH_PREFIX}")
    ```

    `/aws-implementation/ff-state-implementation`
    ```bash
    (aws configure --profile ff list > /dev/null) || (echo "Not configured! Configure ff awscli profile!"; exit 1)
    # or we could do instead:
    source my-custom-lib; aws::verify-configuration;

    aws ec2 describe-instances | jq do-some-formating
    aws elb describe-load-balancers | jq do-some-formating
    # imagine, how easy is to adjust implementation!
    ```

Why not X (terraform, cloudformation, NixOps)?
----------------------------------------------

CloudFormation:
 - to have interactive tool, you have to build someting around CF anyway.
 - no local validation
 - programming language **inside** JSON with no local validation, really?! Who made you to do that?!
 - AWS specific

Terraform:
 - state file
 - cloud agnostic on one hand, but you have to implement specific cloud anyway.
 - modifying the state is sometimes painful, especially when you have custom logic (you probably need to script that around the tool)
 - sometimes is hard to define correct dependencies between resources
 - adding new cloud resources is not that easy

NixOps
 - very opinionated structure of infrastructure
 - state file
 - a lot of cloud resources is missing
 - adding new cloud resources is potentially not as easy as could be

All of them - too much code

Useful tools
============


https://github.com/metal3d/bashsimplecurses

Development / Contributing
--------------------------

Tu run examples and tests, run `nix-shell` to make sure you have all dependencies in local environment.

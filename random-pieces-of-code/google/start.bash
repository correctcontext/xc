ZONE=us-east-1c
# gcloud compute instances list --filter="name=GAN"
gcloud compute instances create \
  GAN \
  --machine-type 
  --zone $ZONE \
  --image-family III \
  --image-project III \


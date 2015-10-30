PROJECT=devops

echo "Managing gitlab directories..." 
./create-storage.sh gitlab-log 2 $PROJECT
echo "gitlab-log created"
./create-storage.sh gitlab-etc 1 $PROJECT
echo "gitlab-etc created"
./create-storage.sh gitlab-opt 10 $PROJECT
echo "gitlab-opt created"

echo "Managing jenkins directories..."
./create-storage.sh jenkins 10 $PROJECT
echo "jenkins created"

echo "Managing nexus directories..."
./create-storage.sh nexus 15 $PROJECT
echo "nexus created"

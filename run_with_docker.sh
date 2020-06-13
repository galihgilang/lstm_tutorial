#!/usr/bin/env bash
set -e
echo "running: $0 $@"

if ! cat /proc/1/cgroup |grep -q docker;then
  if ! docker ps > /dev/null ;then
    DOCKER="sudo docker"
  else
    DOCKER=docker
  fi
  sudo chown $USER -R . || true
fi
mkdir -p tmp
function finish(){
  rm -rf $cmd
  if ! cat /proc/1/cgroup |grep -q docker;then
    sudo chown $USER -R . || true
  fi
}
$DOCKER pull ewckglh/tensorflow:1.0
cmd=.cmd.sh.$RANDOM

echo "
set -e
echo source /root/host/docker_bashrc.sh >> /root/.bashrc
rm -rf $cmd
export TF_CPP_MIN_LOG_LEVEL=0
if [[ ${DEBUG}x != x ]];then
  export DEBUG=$DEBUG
fi
if [[ ${PICKLE}x != x ]];then
  export PICKLE=$PICKLE
fi
cd /root/host/
export PYTHONPATH=\$PWD:\$PWD/bot_utils:\$PWD/n_utils
if [ -f /root/ssh/id_rsa ] && [[ "$COMMIT"x == x ]] && [ -f /root/ssh/id_rsa.pub ];then
  mkdir -p /root/.ssh
  cp /root/ssh/id_rsa /root/.ssh/id_rsa
  cp /root/ssh/id_rsa.pub /root/.ssh/id_rsa.pub
  cp /root/ssh/config /root/.ssh/config
  chmod 700 /root/.ssh
  chmod 600 /root/.ssh/id_rsa*
fi
#if [[ "$1" == *".py"* ]];then
#  shift
#  echo "executing: python3 -m cProfile -o $1.profile $@"
#  python3 -m cProfile -o $1.profile $@
#else
$@
#fi
" > $cmd
echo $cmd

trap finish EXIT
if [[ "$NAME"x != x ]];then
  NAME="--name $NAME"
  docker_args="$docker_args -e JENKINS=1"
fi
if cat /proc/1/cgroup |grep -q docker;then
  echo "We are already in a docker container"
  time bash /root/host/$cmd
else
  # user is able to export docker_args on its own.
  docker_args="$docker_args -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix -v $PWD:/root/host -v $HOME:/root/host-home/"

  docker_args="$docker_args -v /var/run/docker.sock:/var/run/docker.sock"
  if [[ "$COMMIT" != true ]];then
    docker_args="$docker_args --rm"
  fi
  if [[ -f ~/.sp ]];then
    docker_args="$docker_args -v $HOME/.sp:/root/.sp"
  fi
  if [ -f ~/.ssh/id_rsa ] && [[ -f ~/.ssh/config ]] && [[ $HOSTNAME != elx74422t8m ]];then
    docker_args="$docker_args -v $HOME/.ssh/id_rsa:/root/ssh/id_rsa -v $HOME/.ssh/id_rsa.pub:/root/ssh/id_rsa.pub -v $HOME/.ssh/config:/root/ssh/config"
  fi
  # Needed to upload the artifacts with jenkins
  if [[ "$TMP_FOLDER"x != x ]];then
    echo "mounting $TMP_FOLDER"
    docker_args="$docker_args -v $TMP_FOLDER:/root/tmp"
  fi
  docker_args="$docker_args -v /tmp/web-tmp:/tmp/web-tmp"
  if [[ "$1" != "-start" ]];then
      if [ -t 1 ] ; then
        docker_args="$docker_args -it"
      else
        docker_args="$docker_args -i"
      fi
  fi
  # use host's ports
  docker_args="$docker_args --net=host"
  # either just start a sleeping container or one that runs $cmd
  if [[ "$1" == "-start" ]];then
	# start sleeping container
    echo "Only starting the container"
    id=$($DOCKER run -d $docker_args $DOCKERARGS $NAME ewckglh/tensorflow:1.0 sleep 10000000000000000000000)
    echo $id > $2
  else
    time $DOCKER run $docker_args $DOCKERARGS $NAME ewckglh/tensorflow:1.0 bash /root/host/$cmd
  fi
fi

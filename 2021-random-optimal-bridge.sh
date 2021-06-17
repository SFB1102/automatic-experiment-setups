#! /bin/bash
# author: Arne Köhn <arne@chark.eu>
# License: Apache 2.0

# this setting was run with previous data:
# mysqldump --add-drop-table RANDOMOPTIMAL > random-optimal-2021-06-17.sql
# mariadb -> create database RANDOMOPTIMALBRIDGE;
# mariadb RANDOMOPTIMALBRIDGE < random-optimal-2021-06-17.sql
#
# with house games removed:
#
# MariaDB [RANDOMOPTIMALBRIDGE]> delete from GAME_LOGS where gameid in (select id from GAMES where scenario = "house");
# Query OK, 149172 rows affected (0.591 sec)
#
# MariaDB [RANDOMOPTIMALBRIDGE]> delete from GAMES where scenario = "house";
# Query OK, 59 rows affected (0.001 sec)

set -e
set -u

MC_VERSION=1.17
USE_DEV_SERVER=true

SCRIPTDIR=$(cd $(dirname $0); pwd)
source $SCRIPTDIR/functions.sh

SETUP_DIR=${1:-2021-random-optimal-bridge}
mkdir -p $SETUP_DIR
cd $SETUP_DIR


echo "press enter to kill broker, architect and minecraft server."
sleep 1

if [[ ! -f .setup_complete ]]; then
    if [[ -z ${SECRETWORD+x} ]]; then
	echo "You need to declare the secret word before setting up this experiment"
	echo "e.g. SECRETWORD=foo ./2021-trained-weights.sh"
	exit 1
    fi
    echo "running setup before starting the servers"
    rm -rf infrastructure simple-architect spigot-plugin
    setup_spigot_plugin 1a13d9471ed16d3b06a5c2803d9820363b559355
    # setup_spigot_woz_plugin
    setup_infrastructure b55a0d869c226bcaa20d7b626bb91a4252ba543a
    setup_simple-architect a47658febdc124d2168be0ba4951cfc53458a521
    cp ../configs/broker-config-2021-random-optimal-bridge.yaml infrastructure/broker/broker-config.yaml
    if [[ $(hostname) = "minecraft" ]]; then
	# We use an external questionnaire for these experiments
	echo "useInternalQuestionnaire: false" >> infrastructure/broker/broker-config.yaml
    fi
    sed -i "s/secretWord:.*/secretWord: $SECRETWORD/" simple-architect/configs/*yaml
    sed -i "s/MINECRAFTTEST/RANDOMOPTIMALBRIDGE/" simple-architect/configs/*yaml
    # make optimal learn from both optimal and random games to emulate epsilon greedy,
    # reusing the random games for efficiency:
    sed -i "s/weightTrainingArchitectName:.*/weightTrainingArchitectName: \"%\"/" simple-architect/configs/*yaml
    touch .setup_complete
fi

mariadb -u minecraft <<EOF
CREATE DATABASE IF NOT EXISTS RANDOMOPTIMALBRIDGE;
EOF

# this order is important:
# architect -> broker -> mc server

# start_simple-architect
# start_woz
start_simple-architect configs/block-randomized.yaml "10000"
start_simple-architect configs/teaching-randomized.yaml "10001"
start_simple-architect configs/highlevel-randomized.yaml "10002"
start_simple-architect configs/block-optimal.yaml "10003"
start_simple-architect configs/teaching-optimal.yaml "10004"
start_simple-architect configs/highlevel-optimal.yaml "10005"
sleep 5

start_broker
start_mc $MC_VERSION

wait_end
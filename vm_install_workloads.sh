set -eu -o pipefail

sed -i '/^case $- in$/,/^esac$/d' ~/.bashrc
sed -i '1i force_color_prompt=""' ~/.bashrc
sed -i '1i color_prompt=""' ~/.bashrc

echo "SPEC and GAPBS workloads need to be installed manually"

# silo
cd ~
git clone https://github.com/yuhong-zhong/silo.git
cd silo

sudo apt update
sudo apt install libjemalloc-dev libdb++-dev build-essential libaio-dev libnuma-dev libssl-dev zlib1g-dev autoconf -y
MODE=perf make -j dbtest

# faster
cd ~
sudo apt update
sudo apt install libtbb-dev -y
sudo apt install libaio-dev libaio1 uuid-dev libnuma-dev cmake -y

git clone https://github.com/yuhong-zhong/FASTER.git
cd FASTER/cc
mkdir -p build/Release
cd build/Release
cmake -DCMAKE_BUILD_TYPE=Release ../..
make pmem_benchmark

# spark
cd ~
sudo apt update
sudo apt install openjdk-8-jre-headless openjdk-8-jdk-headless -y
echo 'export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64' >> ~/.bashrc
source ~/.bashrc
sudo bash -c "echo 'export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64' >> /etc/environment"
source /etc/environment

cd ~
sudo apt-get install ssh pdsh -y
wget https://dlcdn.apache.org/hadoop/common/hadoop-3.2.4/hadoop-3.2.4.tar.gz
tar -xzvf hadoop-3.2.4.tar.gz
mv hadoop-3.2.4 hadoop

cd hadoop
sed -i "s|<configuration>||" etc/hadoop/core-site.xml
sed -i "s|</configuration>||" etc/hadoop/core-site.xml
echo "<configuration>" >> etc/hadoop/core-site.xml
echo "<property>" >> etc/hadoop/core-site.xml
echo "<name>fs.defaultFS</name>" >> etc/hadoop/core-site.xml
echo "<value>hdfs://localhost:8020</value>" >> etc/hadoop/core-site.xml
echo "</property>" >> etc/hadoop/core-site.xml
echo "</configuration>" >> etc/hadoop/core-site.xml

sed -i "s|<configuration>||" etc/hadoop/hdfs-site.xml
sed -i "s|</configuration>||" etc/hadoop/hdfs-site.xml
cat >> etc/hadoop/hdfs-site.xml <<- End
<configuration>
    <property>
        <name>dfs.replication</name>
        <value>1</value>
    </property>
    <property>
        <name>dfs.datanode.data.dir</name>
        <value>/home/ubuntu/hdfs/datanode</value>
    </property>
</configuration>
End

mkdir -p /home/ubuntu/hdfs/datanode
chmod -R 777 /home/ubuntu/hdfs/datanode

ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 0600 ~/.ssh/authorized_keys

# Formate the filesystem
bin/hdfs namenode -format

echo 'export PDSH_RCMD_TYPE=ssh' >> ~/.bashrc
source ~/.bashrc

sed -i "s|<configuration>||" etc/hadoop/mapred-site.xml
sed -i "s|</configuration>||" etc/hadoop/mapred-site.xml
HADOOP_MAPRED_HOME='$HADOOP_MAPRED_HOME'
cat >> etc/hadoop/mapred-site.xml <<- End
<configuration>
    <property>
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
    </property>
    <property>
        <name>yarn.app.mapreduce.am.env</name>
        <value>HADOOP_MAPRED_HOME=/home/ubuntu/hadoop</value>
    </property>
    <property>
        <name>mapreduce.map.env</name>
        <value>HADOOP_MAPRED_HOME=/home/ubuntu/hadoop</value>
    </property>
    <property>
        <name>mapreduce.reduce.env</name>
        <value>HADOOP_MAPRED_HOME=/home/ubuntu/hadoop</value>
    </property>
    <property>
        <name>mapreduce.application.classpath</name>
        <value>$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/*,$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/lib/*,$HADOOP_MAPRED_HOME/share/hadoop/common/*,$HADOOP_MAPRED_HOME/share/hadoop/common/lib/*,$HADOOP_MAPRED_HOME/share/hadoop/yarn/*,$HADOOP_MAPRED_HOME/share/hadoop/yarn/lib/*,$HADOOP_MAPRED_HOME/share/hadoop/hdfs/*,$HADOOP_MAPRED_HOME/share/hadoop/hdfs/lib/*</value>
    </property>
</configuration>
End

sed -i "s|<configuration>||" etc/hadoop/yarn-site.xml
sed -i "s|</configuration>||" etc/hadoop/yarn-site.xml
cat >> etc/hadoop/yarn-site.xml <<- End
<configuration>
    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
    </property>
    <property>
        <name>yarn.nodemanager.env-whitelist</name>
        <value>JAVA_HOME,HADOOP_COMMON_HOME,HADOOP_HDFS_HOME,HADOOP_CONF_DIR,CLASSPATH_PREPEND_DISTCACHE,HADOOP_YARN_HOME,HADOOP_HOME,PATH,LANG,TZ,HADOOP_MAPRED_HOME</value>
    </property>
</configuration>
End

cd ~
wget https://archive.apache.org/dist/spark/spark-2.4.0/spark-2.4.0-bin-hadoop2.7.tgz
tar -xzvf spark-2.4.0-bin-hadoop2.7.tgz
mv spark-2.4.0-bin-hadoop2.7 spark
cd spark
echo "export SPARK_HOME=$(pwd)" >> ~/.bashrc
echo 'export PATH=$PATH:$SPARK_HOME/bin' >> ~/.bashrc
source ~/.bashrc

cd ~
wget https://mirrors.estointernet.in/apache/maven/maven-3/3.6.3/binaries/apache-maven-3.6.3-bin.tar.gz
tar -xzvf apache-maven-3.6.3-bin.tar.gz
mv apache-maven-3.6.3 apache-maven
cd apache-maven
echo "export M2_HOME=$(pwd)" >> ~/.bashrc
echo 'export PATH=$PATH:$M2_HOME/bin' >> ~/.bashrc
source ~/.bashrc

cd ~
sudo apt-get update
sudo apt-get install bc scala python2 -y

wget https://github.com/Intel-bigdata/HiBench/archive/refs/tags/v7.1.1.tar.gz
tar -xzvf v7.1.1.tar.gz
mv HiBench-7.1.1 HiBench
cd HiBench

cp hadoopbench/mahout/pom.xml hadoopbench/mahout/pom.xml.bak
cat hadoopbench/mahout/pom.xml \
    | sed 's|<repo2>http://archive.cloudera.com</repo2>|<repo2>https://archive.apache.org</repo2>|' \
    | sed 's|cdh5/cdh/5/mahout-0.9-cdh5.1.0.tar.gz|dist/mahout/0.9/mahout-distribution-0.9.tar.gz|' \
    | sed 's|aa953e0353ac104a22d314d15c88d78f|09b999fbee70c9853789ffbd8f28b8a3|' \
    > ./pom.xml.tmp
mv ./pom.xml.tmp hadoopbench/mahout/pom.xml

mvn -Phadoopbench -Psparkbench -Dspark=2.4 -Dscala=2.11 clean package

cp conf/hadoop.conf.template conf/hadoop.conf
sed -i "s|^hibench.hadoop.home.*|hibench.hadoop.home /home/ubuntu/hadoop|" conf/hadoop.conf
echo "hibench.hadoop.examples.jar /home/ubuntu/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.2.4.jar" >> conf/hadoop.conf

cp conf/spark.conf.template conf/spark.conf
sed -i "s|hibench.spark.home.*|hibench.spark.home /home/ubuntu/spark|" conf/spark.conf
sed -i "s|hibench.yarn.executor.num.*|hibench.yarn.executor.num 2|" conf/spark.conf
sed -i "s|hibench.yarn.executor.cores.*|hibench.yarn.executor.cores 2|" conf/spark.conf
sed -i "s|spark.executor.memory.*|spark.executor.memory 2g|" conf/spark.conf
sed -i "s|spark.driver.memory.*|spark.driver.memory 2g|" conf/spark.conf

echo "hibench.masters.hostnames localhost" >> conf/spark.conf
echo "hibench.slaves.hostnames localhost" >> conf/spark.conf

sed -i "s|hibench.scale.profile.*|hibench.scale.profile large|" conf/hibench.conf

# renaissance
cd ~
wget https://github.com/renaissance-benchmarks/renaissance/releases/download/v0.14.2/renaissance-gpl-0.14.2.jar

# dacapo
cd ~
sudo apt-get update
sudo apt-get install default-jre default-jdk openjdk-8-jre openjdk-8-jdk -y

sudo apt-get install ant cvs subversion nodejs npm python3 python3-pip -y
sudo python3 -m pip install colorama future tabulate requests wheel

git clone https://github.com/dacapobench/dacapobench.git
cd dacapobench
git checkout tags/v23.10-RC4-chopin

cd benchmarks
echo "" >> default.properties
echo "jdk.8.home=/usr/lib/jvm/java-8-openjdk-amd64" >> default.properties
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64

sudo rm -f /bin/python
sudo ln -s /bin/python3 /bin/python

# sed -i 's|<target name="compile" depends=.*>|<target name="compile" depends="cassandra,kafka,spring,tomcat,luindex,lusearch">|' build.xml
sed -i 's|<target name="compile" depends=.*>|<target name="compile" depends="cassandra,kafka,spring,tomcat">|' build.xml
sed -i 's|<property name="lib-url" .*>|<property name="lib-url" value="https://archive.apache.org/dist/commons/logging/source/"/>|' libs/commons-logging/build.xml
ant

# tpc-h
cd ~

sudo cp /etc/apt/sources.list /etc/apt/sources.list~
sudo sed -Ei 's/^# deb-src /deb-src /' /etc/apt/sources.list
sudo apt-get update
sudo apt-get build-dep postgresql -y

sudo apt-get install graphviz libreadline-dev zlib1g-dev pgagent libpq5 libssl-dev libxslt1-dev build-essential python2 python2-dev python3-pip -y
sudo apt-get install libwxgtk-media3.0-gtk3-dev -y
sudo pip install sphinxcontrib-htmlhelp

cd ~
wget http://ftp.postgresql.org/pub/source/v9.3.0/postgresql-9.3.0.tar.gz
tar zxvf postgresql-9.3.0.tar.gz
cd postgresql-9.3.0/
CFLAGS="-fno-omit-frame-pointer -rdynamic -O2" ./configure --prefix=/usr/local --enable-debug
make -j$(grep -c ^processor /proc/cpuinfo)
sudo make install

cd ~
git clone https://github.com/pgadmin-org/pgadmin3.git
cd pgadmin3
./bootstrap
CXXFLAGS="-Wno-narrowing" ./configure --prefix=/usr --with-wx-version=3.0 --with-openssl=no
sudo sed -i "s|protected:||" /usr/include/wx-3.0/wx/unix/stdpaths.h
make -j$(grep -c ^processor /proc/cpuinfo)
sudo make install

cd ~
git clone https://github.com/yuhong-zhong/pg-tpch.git
cd pg-tpch
./tpch_prepare

# DLRM
cd ~
sudo apt-get install linux-tools-common linux-tools-generic linux-tools-`uname -r` -y
BASE_DIRECTORY_NAME="dlrm"

rm -rf $BASE_DIRECTORY_NAME
mkdir -p $BASE_DIRECTORY_NAME
cd $BASE_DIRECTORY_NAME
export BASE_PATH=$(pwd)
echo "DLRM-SETUP: FINISHED SETTING UP BASE DIRECTORY"

echo BASE_PATH=$BASE_PATH >> $BASE_PATH/paths.export

wget https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB
sudo apt-key add GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB
echo "deb https://apt.repos.intel.com/oneapi all main" | \
        sudo tee /etc/apt/sources.list.d/oneAPI.list
sudo apt update
sudo apt-get install pkg-config
sudo apt -y install cmake intel-oneapi-vtune numactl python3-pip
sudo sed -i '1i DIAGUTIL_PATH=""' /opt/intel/oneapi/vtune/latest/env/vars.sh
source /opt/intel/oneapi/vtune/latest/env/vars.sh
echo "DLRM-SETUP: FINISHED INSTALLING VTUNE"

cd $BASE_PATH
mkdir -p miniconda3
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh \
        -O miniconda3/miniconda.sh
/usr/bin/bash miniconda3/miniconda.sh -b -u -p miniconda3
rm -rf miniconda3/miniconda.sh
miniconda3/bin/conda init zsh
miniconda3/bin/conda init bash
miniconda3/bin/conda create --name dlrm_cpu python=3.9 ipython -y
echo "DLRM-SETUP: FINISHED INSTALLING CONDA"
source ~/.bashrc

conda install -n dlrm_cpu astunparse cffi cmake dataclasses future mkl mkl-include ninja \
        pyyaml requests setuptools six typing_extensions -y
conda install -n dlrm_cpu -c conda-forge jemalloc gcc=12.1.0 -y
conda run -n dlrm_cpu pip install git+https://github.com/mlperf/logging
conda run -n dlrm_cpu pip install onnx lark-parser hypothesis tqdm scikit-learn
echo "DLRM-SETUP: FINISHED SETTING UP CONDA ENV"

cd $BASE_PATH
git clone --recursive -b v1.12.1 https://github.com/pytorch/pytorch
cd pytorch
conda run --no-capture-output -n dlrm_cpu pip install -r requirements.txt
export CMAKE_PREFIX_PATH=${CONDA_PREFIX:-"$(dirname $(which conda))/../"}
echo CMAKE_PREFIX_PATH=$CMAKE_PREFIX_PATH >> $BASE_PATH/paths.export
export TORCH_PATH=$(pwd)
echo TORCH_PATH=$TORCH_PATH >> $BASE_PATH/paths.export
conda run --no-capture-output -n dlrm_cpu python setup.py develop
echo "DLRM-SETUP: FINISHED BUILDLING PYTORCH"

cd $BASE_PATH
git clone --recursive -b v1.12.300 https://github.com/intel/intel-extension-for-pytorch
cd intel-extension-for-pytorch
export IPEX_PATH=$(pwd)
echo IPEX_PATH=$IPEX_PATH >> $BASE_PATH/paths.export
echo "DLRM-SETUP: FINISHED CLONING IPEX"

cd $BASE_PATH
git clone https://github.com/NERSC/itt-python
cd itt-python
git checkout 3fb76911c81cc9ae5ee55101080a58461b99e11c
export VTUNE_PROFILER_DIR=/opt/intel/oneapi/vtune/latest
echo VTUNE_PROFILER_DIR=$VTUNE_PROFILER_DIR >> $BASE_PATH/paths.export
conda run --no-capture-output -n dlrm_cpu python setup.py install --vtune=$VTUNE_PROFILER_DIR
echo "DLRM-SETUP: FINISHED BUILDLING ITT-PYTHON"

# Set up DLRM inference test.
cd $BASE_PATH
git clone https://github.com/rishucoding/reproduce_isca23_cpu_DLRM_inference
cd reproduce_isca23_cpu_DLRM_inference
export DLRM_SYSTEM=$(pwd)
echo DLRM_SYSTEM=$DLRM_SYSTEM >> $BASE_PATH/paths.export
git clone -b pytorch-r1.12-models https://github.com/IntelAI/models.git
cd models
export MODELS_PATH=$(pwd)
echo MODELS_PATH=$MODELS_PATH >> $BASE_PATH/paths.export
mkdir -p models/recommendation/pytorch/dlrm/product

cp $DLRM_SYSTEM/dlrm_patches/dlrm_data_pytorch.py \
    models/recommendation/pytorch/dlrm/product/dlrm_data_pytorch.py
cp $DLRM_SYSTEM/dlrm_patches/dlrm_s_pytorch.py \
    models/recommendation/pytorch/dlrm/product/dlrm_s_pytorch.py
echo "DLRM-SETUP: FINISHED SETTING UP DLRM TEST"

cd $IPEX_PATH
git apply $DLRM_SYSTEM/dlrm_patches/ipex.patch
find . -type f -exec sed -i 's/-Werror//g' {} \;
USE_NATIVE_ARCH=1 CXXFLAGS="-D_GLIBCXX_USE_CXX11_ABI=0" conda run --no-capture-output -n dlrm_cpu python setup.py install
echo "DLRM-SETUP: FINISHED BUILDING IPEX"

# redis
cd ~
wget https://github.com/redis/redis/archive/refs/tags/7.2.3.tar.gz
tar -xzvf 7.2.3.tar.gz
mv redis-7.2.3 redis
cd redis
make -j8
sudo bash -c "echo 'vm.overcommit_memory=1' >> /etc/sysctl.conf"
sed -i -e '$a save ""' redis.conf

# memcached
cd ~
sudo apt-get update
sudo apt-get install memcached -y

# ycsb
cd ~
git clone https://github.com/brianfrankcooper/YCSB.git
cd YCSB
mvn -pl site.ycsb:redis-binding -am clean package
mvn -pl site.ycsb:memcached-binding -am clean package

# deathstarbench
cd ~
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg -y

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

sudo apt-get install python3-pip -y
sudo python3 -m pip install asyncio aiohttp

sudo apt-get install libssl-dev libz-dev luarocks lua-socket -y
sudo luarocks install luasocket

git clone https://github.com/delimitrou/DeathStarBench.git
cd DeathStarBench/socialNetwork
sudo docker-compose up -d

cd ../wrk2
make
cd ../socialNetwork

sudo luarocks install luasocket

sudo docker stop $(sudo docker ps -aq)
sudo docker rm $(sudo docker ps -aq)

cd ~
cd DeathStarBench/mediaMicroservices/
sudo docker-compose up -d

cd ../wrk2
make
cd ../mediaMicroservices

sudo docker stop $(sudo docker ps -aq)
sudo docker rm $(sudo docker ps -aq)
sudo docker volume prune -f

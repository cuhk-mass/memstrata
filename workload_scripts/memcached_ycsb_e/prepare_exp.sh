cd /home/ubuntu
rm -f result_*

cd YCSB
sed -i 's/recordcount=.*/recordcount=5000000/' workloads/workloade
sed -i 's/operationcount=.*/operationcount=200000/' workloads/workloade
sed -i 's/requestdistribution=.*/requestdistribution=zipfian/' workloads/workloade

sudo sed -i 's/^-m [0-9]*/-m 8192/' /etc/memcached.conf
sudo systemctl restart memcached.service

python2 ./bin/ycsb load memcached -s -P workloads/workloade -p "memcached.hosts=127.0.0.1" -p "threadcount=2"

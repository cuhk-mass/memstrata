cd /home/ubuntu
rm -f result_*

while [ ! -z "$(pgrep -nf redis)" ]; do
    sudo kill $(pgrep -fn redis)
    sleep 1
done

cd redis
src/redis-server redis.conf > /dev/null 2> /dev/null < /dev/null & 
cd ..
sleep 5

cd YCSB
sed -i 's/recordcount=.*/recordcount=5000000/' workloads/workloade
sed -i 's/operationcount=.*/operationcount=300000/' workloads/workloade
sed -i 's/requestdistribution=.*/requestdistribution=zipfian/' workloads/workloade

python2 ./bin/ycsb load redis -s -P workloads/workloade -p "redis.host=127.0.0.1" -p "redis.port=6379" -p "threadcount=3"

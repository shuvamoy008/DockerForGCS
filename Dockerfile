FROM ubuntu:18.04 AS deps

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get -y update \
 && apt-get -y upgrade \
 && apt-get install -y --no-install-recommends apt-utils \
 && apt-get install -y  wget

ENV HADOOP_VERSION 2.7.3
ENV HADOOP_HOME /opt/hadoop-$HADOOP_VERSION
# Create user for Spark
#RUN useradd -ms /bin/bash spark
#RUN useradd -ms /bin/bash hadoop


user root
WORKDIR /tmp
RUN cd /tmp \
  && wget -q -O- --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 0 \
  "http://archive.apache.org/dist/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz" \
  | tar -xz -C /tmp/ \
 && rm -rf $HADOOP_HOME/share/doc \
 && mv /tmp/hadoop-* /opt/hadoop/
# && chown -R hadoop:hadoop $HADOOP_HOME


RUN apt-get update \
 && apt-get install -y curl unzip \
    python3 python3-setuptools \
 && ln -s /usr/bin/python3 /usr/bin/python
# JAVA

RUN apt-get update \
 && apt-get install -y openjdk-8-jre \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*


ENV SPARK_VERSION 2.4.5
ENV SPARK_HOME /opt/spark

ENV SPARK_DIST_CLASSPATH="$HADOOP_HOME/etc/hadoop/*:$HADOOP_HOME/share/hadoop/common/lib/*:$HADOOP_HOME/share/hadoop/common/*:$HADOOP_HOME/share/hadoop/hdfs/*:$HADOOP_HOME/share/hadoop/hdfs/lib/*:$HADOOP_HOME/share/hadoop/hdfs/*:$HADOOP_HOME/share/hadoop/yarn/lib/*:$HADOOP_HOME/share/hadoop/yarn/*:$HADOOP_HOME/share/hadoop/mapreduce/lib/*:$HADOOP_HOME/share/hadoop/mapreduce/*:$HADOOP_HOME/share/hadoop/tools/lib/*"

ENV PATH $PATH:${SPARK_HOME}/bin

RUN curl -sL --retry 3 \
  "https://downloads.apache.org/spark/spark-2.4.5/spark-2.4.5-bin-hadoop2.7.tgz" \
  | gunzip \
  | tar x -C /usr/ \
 && mv /usr/spark-2.4.5-bin-hadoop2.7 $SPARK_HOME

WORKDIR /tmp
RUN cd /tmp \
  && wget https://oak-tree.tech/documents/59/kubernetes-client-4.6.4.jar \
  && wget https://oak-tree.tech/documents/58/kubernetes-model-4.6.4.jar \
  && wget https://oak-tree.tech/documents/57/kubernetes-model-common-4.6.4.jar \
  && rm -rf /opt/spark/jars/kubernetes-client-* \
  && rm -rf /opt/spark/jars/kubernetes-model-* \
  && rm -rf /opt/spark/jars/kubernetes-model-common-* \
  && mv /tmp/kubernetes-* /opt/spark/jars/

RUN set -ex && \
    apt-get update && \
    ln -s /lib /lib64 && \
    apt install -y bash tini libc6 libpam-modules libnss3 && \
   ln -sv /bin/bash /bin/sh && \
    ln -sv /usr/bin/tini /sbin/tini && \
    echo "auth required pam_wheel.so use_uid" >> /etc/pam.d/su && \
    chgrp root /etc/passwd && chmod ug+rw /etc/passwd 

ADD guava-23.0.jar \
    kafka-clients-2.2.1.jar \
    avro-1.8.0.jar \
    kafka_2.11-2.3.0.jar \
    spark-avro_2.11-2.4.0.jar  /opt/spark/jars/

ADD elasticsearch-spark-20_2.11-6.8.7.jar spark-bigquery-with-dependencies_2.11-0.14.0-beta.jar spark-sql-kafka-0-10_2.11-2.4.0.jar  /opt/spark/jars/
ADD sam.avsc myjson.json /opt/
ADD entrypoint.sh /opt/
ENV GS_PROJECT_ID=serene-radius-275116

RUN echo "export LD_LIBRARY_PATH=/opt/hadoop/lib/native/" >> /opt/spark/conf/spark-env.sh
RUN export $LD_LIBRARY_PATH

WORKDIR /opt/spark/work-dir
RUN chmod g+w /opt/spark/work-dir
RUN chmod +x /opt/spark/sbin/
ENTRYPOINT [ "/opt/entrypoint.sh" ]

# Specify the User that the actual main process will run as
USER ${spark_uid}


RabbitMQ Configuration Script
-----------------------------

This script aims to manage the RabbitMQ server configuration.

Examples
--------

To learn how use this script, please check the following examples.
Before moving to the following examples, please make sure the rabbitmq is running.

```
## in case of the docker,
$ sudo docker pull rabbitmq:3.8.9-management
$ sudo docker run -it -d --rm --name solr -p 8983:8983 rabbitmq:3.8.9-management
```

## Assumptions

If you would like to use the RabbitMQ server with your "webapp" application, 
we assumes the followings;

1. Your application uses the "webapp" user connecting to the RabbitMQ server.
2. Your application uses the "/webapp" virtual host only. It means all of your queues and exchanges are defined under this virutla host.
3. Your application uses some queues with a name like webapp.xxxx.
4. All queues use the same dead letter exchange with a name like webapp.dlx.
5. All queues use the same exchange with a name like webapp.
6. The routing key of exchanges has the same name of the corresponding queue.

## Configuration example

```
```

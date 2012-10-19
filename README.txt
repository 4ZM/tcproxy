This script sets up an IP Proxy for testing how server and client applications handle network deterioration.

Here is an example. Let's add latency and some package loss to this config:

server 192.168.1.23 <-> application 192.168.1.69

Start the script on some other interface with:

$ sudo ./tcproxy.sh --dst 192.168.1.23 --latency 400ms --loss 1.0%

Next, configure the application to connect to the proxy instead of the server (it will forward all traffic to the server).

Now we have this config:

server 192.168.1.23 <-> test proxy <-> application 192.168.1.69

#!/bin/bash

echo "Launching virtual machines"

vagrant up

if [ $? -eq 0 ]; then
    echo "192.168.56.110 app1.com app2.com app3.com" | sudo tee -a /etc/hosts
    echo "Virtual machines launched and /etc/hosts updated"
    echo "Use to access the applications:"
    echo "http://app1.com"
    echo "http://app2.com"
    echo "http://app3.com"
else
    echo "Error launching virtual machines"
fi
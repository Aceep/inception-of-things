#!/bin/bash

echo "Destroying virtual machines"

vagrant halt -f
vagrant destroy -f
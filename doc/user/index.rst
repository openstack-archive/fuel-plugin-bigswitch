.. Fuel BigSwitch plugin documentation master file, created by
   sphinx-quickstart on Sun Feb 21 03:14:36 2016.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

Welcome to Fuel BigSwitch plugin's documentation!
=================================================

Fuel BigSwitch plugin allows you to deploy Openstack cluster with BigSwitch's
BCF SND networking fabric.

In P-Only mode, plugin installs Neutron BigSwitch ML2 mechanism driver for
vlan segmentation.

In P+V mode, in addition to the BigSwitch ML2 mechanism driver, plugin also installs 
L3 service plugin which allows routers to be created in BCF.

Plugin can work with BCF 3.5.

Plugin versions:

* 1.x.x series is compatible with Fuel 7.0.

Contents:

.. toctree::
   :maxdepth: 2

   source/build
   source/installation
   source/environment
   source/configuration
   source/usage
   source/release-notes


Indices and tables
==================

* :ref:`genindex`
* :ref:`modindex`
* :ref:`search`


..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

===========================================================
Fuel Plugin v1.0.0 for BigSwitch BCF SDN Fabric integration
===========================================================

BigSwitch plugin for Fuel provides an ability to deploy OpenStack cluster that is
utilizing BigSwitch Big Cloud Fabric network virtualization platform.

Problem description
===================

Proposed change
===============

Implement a Fuel plugin [1]_ which will deploy BigSwitch plugin as a P-only fabric
for OpenStack networking service (Neutron) and configure it.

Plugin assumes that end user already has BigSwitch Big Cloud Fabric running

Plugin components will include:

- puppet manifests for installation and configuration Neutron BigSwitch plugin

Architecture diagram

::

                                            +----------------------------+
                                            |  Compute cluster           |
                                            |                            |
                            OpenStack       |   +--------------------+   |
                            Public network  |   |                    |   |   VLAN Segment
 +----------------------+          +        |   |   KVM host +-----+ |   |     +
 |                      |          |        |   |            |     | |   |     |
 | OpenStack Controller |          |        |   |            | VM  +-----------+
 |                      |          |        |   |            |     | |   |     |
 | +------------------+ |          |        |   |            +-----+ |   |     |
 | |                  | |          |        |   +--------------------+   |     |
 | | Neutron server   | |          |        |                            |     | 
 | |                  | |          |        |                            |     | 
 | |    +-----------+ | |          |        |                            |     | 
 | |    |           | | |          |        |                            |     | 
 | |    | BigSwitch | | +----------+        |                            |     |
 | |    | plugin    | | |          |        |   +--------------------+   |     |
 | |    |           | | |          |        |   |            +-----+ |   |     |
 | |    +-----------+ | |          |        |   | KVM  host  |     | |   |     |
 | |                  | |          |        |   |            | VM  +-----------+
 | +------------------+ |          |        |   |            |     | |   |     |
 +----------------------+          |        |   |            +-----+ |   |     |
                                   |        |   +--------------------+   |     |
                                   |        |                            |     |
                                   |        |   +--------------------+   |     |
                                   |        |   |                    |   |     |
                                   |        |   | KVM  host  +-----+ |   |     |
                                   |        |   |            |     | |   |     |
                                   |        |   |            | VM  +-----------+
                                   |        |   |            |     | |   |     |
                                   |        |   |            +-----+ |   |     |
                                   |        |   +--------------------+   |     |
                                   |        +----------------------------+     |
                                   |                                           |
                                   |        +----------------------------+     |
                                   |        |                            |     |
                                   +--------+  BigSwitch BCF Controller  |     | 
                                   |        |            Cluster         |     |
                                   |        |                            |     | 
                                   +        +----------------------------+     +




VM creation workflow:

::

                                 Neutron server
  Nova-api      Nova-compute  (BigSwitch plugin)  BigSwitch Controller
      +            +                   +               +
      |            |                   |               |
      |            |                   |               |
      | Create VM  |                   |               | 
      |            |                   |               |
      | <--------> |   Provision port  |               |
      |            |   for VM          |               |
      |            |  <------------->  |               |
      |            |                   |  Create port  |
      |            |                   | <-----------> +---+
      |            |                   |               |   |
      |            |                   | Port ready    |   |
      |            |  Port with UUID N | <-----------> +---+
      |            |  ready            |               |   
      |            |  <------------->  |               |  
      |            |                   |               | 
      |            |                   |               |
      |            |  Create VM and attach to port with UUID N
      |            | <-------------------------------> |
      |            |                   |               |                 |
      +            +                   +               +                 +


Plugin work items in pre-deployment stage:

  - Install lldp daemon to form LACP lag groups for openstack controllers and compute nodes

Plugin actions in post-deployment stage:

#. Stop nova-network pacemaker resource
#. Configure neutron-server with notification
#. Configure keystone with notification
#. Install Neutron BigSwitch plugin
#. Configure the plugin
#. Start Neutron server

Deployment diagram:

::

 BigSwitch manifests                 Neutron-server

       +                             +
       |  Configure LLDP Daemons on  |
       |  Controllers and Computes   |
       |                             |
       |  Prepare data for Neutron   |
       |  deployment tasks           |
       |                             |
       |  Stop Neutron agents        |
       |  pacemaker resource         |
       |  +------------------------> +
       |
       |  Install BigSwitch plugin
       |
       |  Configure neutron-server with BigSwitch
       |
       |  Start Neutron-server
       |  +------------------------->+
       |                             |
       |  Start Neutron agents       |
       |  pacemaker resource         |
       |                             |
       |                             |
       v                             v


Plugin will be compatible with Fuel 7.0.


Alternatives
------------

None.

Data model impact
-----------------

Plugin will produce following array of settings into astute.yaml:

.. code-block:: yaml

  bigswitch

REST API impact
---------------

None.

Upgrade impact
--------------

None.

Security impact
---------------

None.

Notifications impact
--------------------

None.

Other end user impact
---------------------

Plugin settings are available via the Settings tab on Fuel web UI.

Performance Impact
------------------

None.

Other deployer impact
---------------------

None.

Developer impact
----------------

Implementation
==============

Assignee(s)
-----------

Primary assignee:

- Kanzhe Jiang <kanzhe.jiang@bigswitch.com> - developer


Work Items
----------

* Create pre-dev environment and manually deploy BCF

* Create Fuel plugin bundle, which contains deployments scripts, puppet
  modules and metadata

* Implement puppet module with the following functions:

 - Install Neutron BigSwitch plugin on OpenStack controllers
 - Configure Neutron server to use BigSwitch plugin and reload its configuration
 - Create needed networks for OpenStack testing framework (OSTF)

* Create system test for the plugin

* Write documentation


Dependencies
============

* Fuel 7.0

Testing
=======

* Sanity checks including plugin build
* Syntax check
* Functional testing

Documentation Impact
====================

* Deployment Guide (how to prepare an env for installation, how to
  install the plugin, how to deploy OpenStack env with the plugin)
* User Guide (which features the plugin provides, how to use them in
  the deployed OS env)

References
==========

.. [1] Fuel Plug-in Guide http://docs.mirantis.com/openstack/fuel/fuel-7.0/plugin-dev.html
.. [2] https://github.com/openstack/fuel-library

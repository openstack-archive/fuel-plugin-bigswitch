Configuration
=============

Switch to Settings tab of the Fuel web UI and click on "BigSwitch Networking Plugin"
section, tick the plugin checkbox to enable it.

.. image:: /image/bsn-plugin-configuration-page.png
   :scale: 60 %

Plugin contains the following settings:

#. Fabric Mode -- Big Switch Big Cloud Fabric can be deployed as a p-only
   (physical-only) fabric, which manages all the physical switches, or p+v
   (physical and virtual) fabric, which manages all the physical and virtual
   switches.
   In P-only mode, BCF is a L2-only fabric in VLAN mode. L3-agent will provide
   the routing function.
   In P+V mode, BCF is a L2-and-L3 fabric in VLAN mode. All compute nodes will
   install SL-v (Switch Light virtual) switches. All the SL-v switches and
   physical switches will be managed by BCF SDN controller cluster. In P+V mode,
   fuel bigswitch plugin will automatically un-install OVS and install SL-v
   switches on all compute nodes.

  
#. BCF Controller1 -- This is the IP address of the first BCF controller in the
   controller cluster. This is a required field. If the controller cluster only
   has one controller, this is the place to enter the controller IP address.

#. BCF Controller2 -- This is the IP address of the second BCF controller in the
   controller cluster. This is an optional field. If it is empty, then BCF
   controller is in standalone mode.

#. BCF Controller Username -- The username to access BCF controller's REST APIs

#. BCF Controller Password -- The password to access BCF controller's REST APIs

#. Openstack Instance ID -- The ID of the Openstack instance. Mulitple cloud
   orchestration systems can share the same BCF fabric. This field is to identify
   the orchestration system.

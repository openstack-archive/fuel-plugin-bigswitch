OpenStack environment notes
===========================

Environment creation
--------------------

For every new deployment environment, please maually create logical
networks for pxe, public, management, and storage network. The VLAN
assignment for the above network must match the membership
configuration of the corresponding BCF logical networks.

   .. image:: /image/BCF_prep.png
      :scale: 70 %

#. In the environment setup wizard, Network setup step, make sure to
   select "Neutron with VLAN segmentation".

   .. image:: /image/Vlan-segmentation.png
      :scale: 70 %

#. After adding each node, if the node's pnics are bonded, LACP mode
   is recommended. The node can be controller, storage, or compute.

   .. image:: /image/interface-bond.png
      :scale: 70 %


Pay attention on which interface you assign *Public* network, OpenStack
controllers must have connectivity with BigSwitch BCF controllers through
public network since it is used as default route for packets.


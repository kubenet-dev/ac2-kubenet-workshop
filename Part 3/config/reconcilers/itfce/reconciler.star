def reconcile(self):
  node = self
  # check if the condition is ready
  if is_conditionready(self, "IPClaimReady") != True:
    return reconcile_result(self, True, 0, "ip claim not ready", False)

  partition = node.get("spec", {}).get("partition", "")
  namespace = node.get("metdata", {}).get("namespace", "")
  ipindex_name = ".".join([partition, "default"])

  ipindex, err = get_ipindex(ipindex_name, namespace)
  if err != None:
    # we will be retriggered when the ipindex get ready -> dont retrun the err
    return reconcile_result(self, False, 0, "", False)

  for itfce in get_node_interfaces(node):
    rsp = client_create(itfce)
    if rsp["error"] != None:
      return reconcile_result(self, True, 0, rsp["error"], rsp["fatal"])
  
  subinterface, err = get_node_subinterface(self, ipindex)
  if err != None:
    return reconcile_result(self, True, 0, err, False)
  rsp = client_create(subinterface)
  if rsp["error"] != None:
    return reconcile_result(self, True, 0, rsp["error"], rsp["fatal"])
  
  return reconcile_result(self, False, 0, "", False)

def get_node_interfaces(node):
  namespace = node.get("metadata", {}).get("namespace", "")
  node_name = node.get("metadata", {}).get("name", "")
  node_spec = node.get("spec", {})

  interfaces = []
  for ifname in ["system", "irb"]:
    interface = {
      "apiVersion": "device.network.kubenet.dev/v1alpha1",
      "kind": "Interface",
      "metadata": {
          "name": ".".join([node_name, str(0), str(0), ifname]),
          "namespace": namespace,
      },
      "spec": {
        "partition": node_spec.get("partition", ""),
        "region": node_spec.get("region", ""),
        "site": node_spec.get("site", ""),
        "node": node_spec.get("node", ""),
        "provider": node_spec.get("provider", ""),
        "platformType": node_spec.get("platformType", ""),
        "port": 0,
        "endpoint": 0,
        "name": ifname,
        "vlanTagging": False,
        "mtu": 9000,
      },
    }
    interfaces.append(interface)
  return interfaces

def get_node_subinterface(node, ipindex):
  namespace = node.get("metadata", {}).get("namespace", "")
  node_name = node.get("metadata", {}).get("name", "")
  node_spec = node.get("spec", {})

  addresses_ipv4 = None
  addresses_ipv6 = None
  for af, enabled in get_enabled_afs(ipindex).items():
    if enabled:
      address, err = get_ipclaim(".".join([node_name, af]), namespace) 
      if err != None:
          return None, err
      if af == "ipv4":
        addresses_ipv4 = {"addresses": [address]}
      if af == "ipv6":
        addresses_ipv6 = {"addresses": [address]}
  si = {
    "apiVersion": "device.network.kubenet.dev/v1alpha1",
    "kind": "SubInterface",
    "metadata": {
        "name": ".".join([node_name, str(0), str(0), str(0), "system"]),
        "namespace": namespace,
    },
    "spec": {
      "partition": node_spec.get("partition", ""),
      "region": node_spec.get("region", ""),
      "site": node_spec.get("site", ""),
      "node": node_spec.get("node", ""),
      "provider": node_spec.get("provider", ""),
      "platformType": node_spec.get("platformType", ""),
      "port": 0,
      "endpoint": 0,
      "name": "system",
      "id": 0,
      "enabled": True,
      "type": "routed",
    },
  }
  if addresses_ipv4 != None:
    si["spec"]["ipv4"] = addresses_ipv4
  if addresses_ipv6 != None:
    si["spec"]["ipv6"] = addresses_ipv6
  return si, None


def get_ipclaim(name, namespace):
  resource = get_resource("ipam.be.kuid.dev/v1alpha1", "IPClaim")
  rsp = client_get(name, namespace, resource["resource"])
  if rsp["error"] != None:
    return None, "ipclaim " + name + " err: " + rsp["error"]
  
  if is_conditionready(rsp["resource"], "Ready") != True:
    return None, "ipclaim " + name + " not ready"
  address = rsp["resource"].get("status", {}).get("address", "")
  if address == "":
    return None, "ipclaim " + name + " no address in ip claim"
  return address, None

def get_ipindex(name, namespace):
  resource = get_resource("ipam.be.kuid.dev/v1alpha1", "IPIndex")
  rsp = client_get(name, namespace, resource["resource"])
  if rsp["error"] != None:
    return None, "ipindex " + name + " err: " + rsp["error"]
  
  if is_conditionready(rsp["resource"], "Ready") != True:
    return None, "ipindex " + name + " not ready"
  return rsp["resource"], None

def get_enabled_afs(ipindex):
  afs = {
    "ipv4": False,
    "ipv6": False,
  }
  for prefix in ipindex.get("spec", {}).get("prefixes", []):
    if isIPv4(prefix.get("prefix", "")):
      afs["ipv4"] = True
    if isIPv6(prefix.get("prefix", "")):
      afs["ipv6"] = True
  return afs
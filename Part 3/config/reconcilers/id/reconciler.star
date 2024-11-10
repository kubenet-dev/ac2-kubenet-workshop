def reconcile(self):
  # self is node
  node = self
  
  partition = node.get("spec", {}).get("partition", "")
  namespace = node.get("metdata", {}).get("namespace", "")
  ipindex_name = ".".join([partition, "default"])

  ipindex, err = get_ipindex(ipindex_name, namespace)
  if err != None:
    # we will be retriggered when the ipindex get ready -> dont retrun the err
    return reconcile_result(self, False, 0, "", False)
        
  ip_claims = get_ipclaims(node, ipindex)
  for ip_claim in ip_claims:
    rsp = client_create(ip_claim)
    if rsp["error"] != None:
        return reconcile_result(self, True, 0, rsp["error"], rsp["fatal"])

  return reconcile_result(self, False, 0, "", False)

def get_ipindex(name, namespace):
  resource = get_resource("ipam.be.kuid.dev/v1alpha1", "IPIndex")
  rsp = client_get(name, namespace, resource["resource"])
  if rsp["error"] != None:
    return None, "ipindex " + name + " err: " + rsp["error"]
  
  if is_conditionready(rsp["resource"], "Ready") != True:
    return None, "ipindex " + name + " not ready"
  return rsp["resource"], None


def get_ipclaims(node, ipindex):
  node_name = node.get("metadata", {}).get("name", "")
  namespace = node.get("metadata", {}).get("namespace", "")
  index = ipindex.get("metadata", {}).get("name", "")
  ip_claims = []

  for af, enabled in get_enabled_afs(ipindex).items():
    if enabled:
      ip_claims.append(get_ipclaim(node_name, namespace, index, af))
  return ip_claims

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

def get_ipclaim(name, namespace, index, af):
  return {
    "apiVersion": "ipam.be.kuid.dev/v1alpha1",
    "kind": "IPClaim",
    "metadata": {
      "namespace": namespace,
      "name": ".".join([name, af]),
    },
    "spec": {
      "index": index,
      "prefixType": "pool",
      "selector": {
        "matchLabels": {
          "infra.kuid.dev/purpose": "loopback",
          "ipam.be.kuid.dev/address-family": af,
        },
      },
    },
  }
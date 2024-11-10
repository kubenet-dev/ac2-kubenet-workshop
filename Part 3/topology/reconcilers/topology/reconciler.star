load("topo.kubenet.dev.topologies.star", "build_node", "build_link")

def reconcile(self):
  
  # gathers all nodes in a dict for the links to perforn a convenient lookup
  nodes = {}
  for topo_node in self.get("spec", {}).get("nodes", []):
    node = build_node(self, topo_node)
    # add the nodes to the dict so the link transformer
    # can perform the lookup to find its data
    nodes[node.get("spec", {}).get("node", "")] = node
    rsp = client_create(node)
    if rsp["error"] != None:
      return reconcile_result(self, True, 0, rsp["error"], rsp["fatal"])
  
  for topo_link in self.get("spec", {}).get("links", []):
    link, err = build_link(self, topo_link, nodes)
    if err != None:
      return reconcile_result(self, True, 0, err, True)
    rsp = client_create(link)
    if rsp["error"] != None:
      return reconcile_result(self, True, 0, rsp["error"], rsp["fatal"])
  
  return reconcile_result(self, False, 0, "", False)

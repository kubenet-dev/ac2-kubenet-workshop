def reconcile(self):
  # self = helloworld

  self['spec'] = {"greeting": "hello choreo"}
  return reconcile_result(self, False, 0, "", False)
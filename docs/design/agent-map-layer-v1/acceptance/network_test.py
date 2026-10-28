import importlib.util,pathlib,unittest,urllib.request
spec=importlib.util.spec_from_file_location('map_network',pathlib.Path(__file__).with_name('network.py'));module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
class RedirectTests(unittest.TestCase):
 def test_cross_origin_never_gets_authorization(self):
  request=urllib.request.Request('https://api.deepseek.com/v1/chat/completions',headers={'Authorization':'Bearer unit-test-only'})
  self.assertIsNone(module.NoRedirect().redirect_request(request,None,302,'redirect',{},'https://other.invalid/steal'))
 def test_https_downgrade_rejected(self):
  request=urllib.request.Request('https://api.deepseek.com/v1/chat/completions',headers={'Authorization':'Bearer unit-test-only'})
  self.assertIsNone(module.NoRedirect().redirect_request(request,None,307,'redirect',{},'http://api.deepseek.com/steal'))
if __name__=='__main__':unittest.main()

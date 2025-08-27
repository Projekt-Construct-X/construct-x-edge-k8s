## TL;DR

```bash
cd construct-x-edge
helm dependency build ../edc
helm dependency build .
helm install edc  -f values.yaml --debug .
```


### Known Knowns

#### Missing Dependencies
- In case the deployment has issues with the missing dependencies, comment out the ***.tgz** extension from the .helmignore file
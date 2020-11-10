# Vault Plugin Lifecycle

Not much has been written on the mechanics of Vault plugins. Here is what I know:

* The plugin is implemented as a separate process from Vault. The plugin is forked (started) when a path that the binary services is accessed. Merely mounting a plugin doesn't fork the executable.

* When you disable a plugin, you destroy the storage that the plugin was managing. So, don't disable the plugin unless you want that to happen.

* When you register a plugin, you are telling Vault that you trust this particular binary. You do this by registering the shasum of the plugin into Vault:

```sh
export SHA256=$(shasum -a 256 "$HOME/etc/vault.d/plugins/immutability-eth-plugin" | cut -d' ' -f1)
vault write sys/plugins/catalog/secret/immutability-eth-plugin \
      sha_256="${SHA256}" \
      command="immutability-eth-plugin --ca-cert=$HOME/etc/vault.d/root.crt --client-cert=$HOME/etc/vault.d/vault.crt --client-key=$HOME/etc/vault.d/vault.key"
```

* When Vault starts, it tries to mount any previously enabled plugins. If the checksum of the binary doesn't match, the plugin won't be mounted. The storage still exists however.

* Once a plugin process is forked, Vault ceases to verify the checksum of the plugin. This is because the plugin is running and all Vault needs to do is use GRPC to talk to it.

So what does all this mean?

It means that there are some counterintuitive lifecycles that need to be accommodated for. I will walk through each of these. Below, notice that the plugin process is not running until step 4.

## Initial Enablement/Registration

This is the baseline sequence. Consider 2 versions of the plugin: `immutability-eth-plugin.v1` and `immutability-eth-plugin.v2`

1. Start Vault

```
$ vault secrets list
Path          Type         Accessor              Description
----          ----         --------              -----------
cubbyhole/    cubbyhole    cubbyhole_ae57dff1    per-token private secret storage
identity/     identity     identity_c32747ea     identity store
sys/          system       system_a44b47c0       system endpoints used for control, policy and debugging

$ ps -eaf | grep -i vault
  501 51018 45209   0  8:10AM ttys002    0:00.00 grep --color=auto --exclude-dir=.bzr --exclude-dir=CVS --exclude-dir=.git --exclude-dir=.hg --exclude-dir=.svn --exclude-dir=.idea --exclude-dir=.tox -i vault
  501 50977     1   0  8:09AM ttys003    0:00.09 /usr/local/bin/vault server -config /Users/immutability/etc/vault.d/vault.hcl -log-level=debug
```

2. Register `immutability-eth-plugin.v1` (shasum is in the catalog)

```sh
$ export SHA256=$(shasum -a 256 "$HOME/etc/vault.d/plugins/immutability-eth-plugin.v1" | cut -d' ' -f1)

$ vault write sys/plugins/catalog/secret/immutability-eth-plugin \
      sha_256="${SHA256}" \
      command="immutability-eth-plugin.v1 --ca-cert=$HOME/etc/vault.d/root.crt --client-cert=$HOME/etc/vault.d/vault.crt --client-key=$HOME/etc/vault.d/vault.key"
Success! Data written to: sys/plugins/catalog/secret/immutability-eth-plugin

$ vault secrets list
Path          Type         Accessor              Description
----          ----         --------              -----------
cubbyhole/    cubbyhole    cubbyhole_ae57dff1    per-token private secret storage
identity/     identity     identity_c32747ea     identity store
sys/          system       system_a44b47c0       system endpoints used for control, policy and debugging

$ ps -eaf | grep -i vault
  501 51155 45209   0  8:11AM ttys002    0:00.00 grep --color=auto --exclude-dir=.bzr --exclude-dir=CVS --exclude-dir=.git --exclude-dir=.hg --exclude-dir=.svn --exclude-dir=.idea --exclude-dir=.tox -i vault
  501 50977     1   0  8:09AM ttys003    0:00.16 /usr/local/bin/vault server -config /Users/immutability/etc/vault.d/vault.hcl -log-level=debug
```

3. Enable `immutability-eth-plugin.v1` (`immutability-eth-plugin.v1` is mounted)

```sh
$ vault secrets enable -path=immutability-eth-plugin -plugin-name=immutability-eth-plugin plugin
Success! Enabled the immutability-eth-plugin secrets engine at: immutability-eth-plugin/

$ vault secrets list
Path                        Type                       Accessor                            Description
----                        ----                       --------                            -----------
cubbyhole/                  cubbyhole                  cubbyhole_ae57dff1                  per-token private secret storage
identity/                   identity                   identity_c32747ea                   identity store
immutability-eth-plugin/    immutability-eth-plugin    immutability-eth-plugin_4d20867f    n/a
sys/                        system                     system_a44b47c0                     system endpoints used for control, policy and debugging

$ ps -eaf | grep -i vault
  501 51186 45209   0  8:11AM ttys002    0:00.00 grep --color=auto --exclude-dir=.bzr --exclude-dir=CVS --exclude-dir=.git --exclude-dir=.hg --exclude-dir=.svn --exclude-dir=.idea --exclude-dir=.tox -i vault
  501 50977     1   0  8:09AM ttys003    0:00.28 /usr/local/bin/vault server -config /Users/immutability/etc/vault.d/vault.hcl -log-level=debug
```

4. Access `immutability-eth-plugin.v1` (`immutability-eth-plugin.v1` is running)

```sh
$ vault read  immutability-eth-plugin/config
Error reading immutability-eth-plugin/config: Error making API request.

URL: GET https://localhost:8200/v1/immutability-eth-plugin/config
Code: 500. Errors:

* 1 error occurred:
	* the Ethereum backend is not configured properly

$ ps -eaf | grep -i vault
  501 51491 45209   0  8:18AM ttys002    0:00.00 grep --color=auto --exclude-dir=.bzr --exclude-dir=CVS --exclude-dir=.git --exclude-dir=.hg --exclude-dir=.svn --exclude-dir=.idea --exclude-dir=.tox -i vault
  501 51324     1   0  8:15AM ttys003    0:00.54 /usr/local/bin/vault server -config /Users/immutability/etc/vault.d/vault.hcl -log-level=debug
  501 51478 51324   0  8:17AM ttys003    0:00.11 /Users/immutability/etc/vault.d/plugins/immutability-eth-plugin.v1 --ca-cert=/Users/immutability/etc/vault.d/root.crt --client-cert=/Users/immutability/etc/vault.d/vault.crt --client-key=/Users/immutability/etc/vault.d/vault.key

$ vault write -f  immutability-eth-plugin/config rpc_url="http://localhost:8485"
Key                Value
---                -----
blacklist          <nil>
bound_cidr_list    <nil>
chain_id           4
rpc_url            http://localhost:8485
whitelist          <nil>
```

**NOTE:** The plugin wasn't started until the `immutability-eth-plugin/config` path was accessed.

## Update plugin

Assuming that Vault and the `immutability-eth-plugin.v1` plugin are running, we can pull at the strings a bit examine behaviors:

### Build `immutability-eth-plugin.v2`

If we copy `immutability-eth-plugin.v2` to the plugins directory, nothing is affected since we haven't told Vault about it. 

```
$ ls -la
total 122512
drwxr-xr-x   4 immutability  staff       128 Nov 10 08:28 .
drwxr-xr-x  21 immutability  staff       672 Nov 10 08:15 ..
-rwxr-xr-x   1 immutability  staff  31360192 Nov 10 08:16 immutability-eth-plugin.v1
-rwxr-xr-x   1 immutability  staff  31360192 Nov 10 08:28 immutability-eth-plugin.v2
```

However, what happens if we replace `immutability-eth-plugin.v1` with `immutability-eth-plugin.v2`?


```sh
$ export SHA256=$(shasum -a 256 "$HOME/etc/vault.d/plugins/immutability-eth-plugin.v1" | cut -d' ' -f1)
$ echo $SHA256
25bf36fa15411ea5732ad2349cfc32abec79b815ca54347c824939614717a9e3

$ export SHA256=$(shasum -a 256 "$HOME/etc/vault.d/plugins/immutability-eth-plugin.v2" | cut -d' ' -f1)
$ echo $SHA256
64953e1a71715f67393599eaf6990f2b3e80b7b5e87e5ee9260b9699031552bf

$ cp immutability-eth-plugin.v1 immutability-eth-plugin.v1.bak
$ cp immutability-eth-plugin.v2 immutability-eth-plugin.v1

```

The checksums don't match. But, when we try to access the `immutability-eth-plugin/config` path, everything seems to work:

```sh
$ vault read  immutability-eth-plugin/config
Key                Value
---                -----
blacklist          <nil>
bound_cidr_list    <nil>
chain_id           4
rpc_url            http://localhost:8485
whitelist          <nil>
```

This is because the original `immutability-eth-plugin.v1` process was never terminated. But if we kill the plugin process, and try again - it fails:

```sh
$ pkill -f immutability-eth-plugin.v1
$ vault read  immutability-eth-plugin/config
Error reading immutability-eth-plugin/config: Error making API request.

URL: GET https://localhost:8200/v1/immutability-eth-plugin/config
Code: 500. Errors:

* 1 error occurred:
	* checksums did not match

```

If we now return `immutability-eth-plugin.v1` to its original state, and try again things are cool:

```sh
$ mv immutability-eth-plugin.v1.bak immutability-eth-plugin.v1

$ vault read  immutability-eth-plugin/config
Key                Value
---                -----
blacklist          <nil>
bound_cidr_list    <nil>
chain_id           4
rpc_url            http://localhost:8485
whitelist          <nil>

```

### Register v2 while v1 is running

So, we have a steady state - `immutability-eth-plugin.v1` was correctly registered when Vault forked the pluging; and so, `immutability-eth-plugin.v1` is running.

What happens if we register `immutability-eth-plugin.v2` while `immutability-eth-plugin.v1` is running?

```sh
$ export SHA256=$(shasum -a 256 "$HOME/etc/vault.d/plugins/immutability-eth-plugin.v2" | cut -d' ' -f1)
$ vault write sys/plugins/catalog/secret/immutability-eth-plugin \
      sha_256="${SHA256}" \
      command="immutability-eth-plugin.v2 --ca-cert=$HOME/etc/vault.d/root.crt --client-cert=$HOME/etc/vault.d/vault.crt --client-key=$HOME/etc/vault.d/vault.key"
Success! Data written to: sys/plugins/catalog/secret/immutability-eth-plugin

$ vault read  immutability-eth-plugin/config
Key                Value
---                -----
blacklist          <nil>
bound_cidr_list    <nil>
chain_id           4
rpc_url            http://localhost:8485
whitelist          <nil>
```

As you can see, the old plugin `immutability-eth-plugin.v1` is still running and works fine.

```sh
$ ps -eaf | grep -i vault
  501 53217 45209   0 11:30AM ttys002    0:00.00 grep --color=auto --exclude-dir=.bzr --exclude-dir=CVS --exclude-dir=.git --exclude-dir=.hg --exclude-dir=.svn --exclude-dir=.idea --exclude-dir=.tox -i vault
  501 51888     1   0  8:31AM ttys003    0:13.21 /usr/local/bin/vault server -config /Users/immutability/etc/vault.d/vault.hcl -log-level=debug
  501 52130 51888   0  8:38AM ttys003    0:01.16 /Users/immutability/etc/vault.d/plugins/immutability-eth-plugin.v1 --ca-cert=/Users/immutability/etc/vault.d/root.crt --client-cert=/Users/immutability/etc/vault.d/vault.crt --client-key=/Users/immutability/etc/vault.d/vault.key
```

Let's bounce Vault, unseal it, and see what Vault thinks now.

```sh
$ kill -9 $(lsof -ti:8200)
$ pkill -f immutability-eth-plugin.v1

# Restart/unseal

$ vault read  immutability-eth-plugin/config
Key                Value
---                -----
blacklist          <nil>
bound_cidr_list    <nil>
chain_id           4
rpc_url            http://localhost:8485
whitelist          <nil>

$ ps -eaf | grep -i vault
  501 54490 44543   0 11:50AM ttys000    0:00.00 grep --color=auto --exclude-dir=.bzr --exclude-dir=CVS --exclude-dir=.git --exclude-dir=.hg --exclude-dir=.svn --exclude-dir=.idea --exclude-dir=.tox -i vault
  501 54410     1   0 11:48AM ttys003    0:00.50 /usr/local/bin/vault server -config /Users/immutability/etc/vault.d/vault.hcl -log-level=debug
  501 54431 54410   0 11:48AM ttys003    0:00.15 /Users/immutability/etc/vault.d/plugins/immutability-eth-plugin.v2 --ca-cert=/Users/immutability/etc/vault.d/root.crt --client-cert=/Users/immutability/etc/vault.d/vault.crt --client-key=/Users/immutability/etc/vault.d/vault.key
```

As we can see, the storage is still there. The new plugin is running.

But the sequence of operations is super important:

* Once a plugin is running (forked), you have to bounce Vault to get a new plugin run.
* You can register a new version of a plugin while the old version is running.
* If you rebuild the plugin - even if there are no code changes - the shasum of the plugin will change. So, if you restore a snapshot with a new build, you have to deal with re-registration.

# Z3 deployment requirements

Zebra + Zaino + Zallet discussion on configuration, secret handling and deployment


Credits: Yass, Nuttycom, Daira-Emma, Str4d, NachoGeo, Gustavo

_Note:_ This document is a recollection from a conversation had by the Z3 developers.

## Assumptions

Zallet is the most _user-facing_ part of Z3. Wise words from ECC Core Dev @nuttycom:

> A really important thing to remember is that some, perhaps many of the people who
> end up running Zallet *will not be sysadmins*. They will be ordinary people with
> computers, potentially _quite security-unconscious_ ordinary people with computers.

## Requirements

- Z3 should be configurable at startup.
- Configuration parameters could be secrets or sensitive information
- Z3 configuration MUST be able to be trusted with _secrets_. 
- Such configuration should not be available to other processes running on the host
  that are not part of Z3.
- Z3's main goal is to support Zallet (otherwise it would be Z2 😅).
- Zallet is inherently stateful while Zebra and Zaino could (in theory) be deployed
  in a stateless fashion via (very periodical) snapshots
- Zallet does NOT require parellelism.
- Zebra, Zaino - those have state that is expensive to recover, so parallelism makes
  sense for them.
- Z3 configuration should be friendly to failover schemes for environments with high-
  availability needs.
- "Wallets are absolutely mission-critical!". (Nuttycom)
- Containerized approach does not force users to rebuild. It's bad DX/UX. (Gustavo)

## Non-requirements
- Establishing a one-fits-all solution. Scaling considerations differ at a Z-level. For
example: Zaino clients may benefit from horizontal scaling solutions whereas Zallet
users would be troubled by having seemingly duplicated instances of a wallet
(anti-pattern / footgun). In between that spectrum, there is no gain for Zebra users
to have one or more Zebra instances in terms of performance.

## Config via environment variables

*Definition*: available configuration parameters are defined on documented environment
variables which are picked up by the process or processes involved in Z3. 

### Advantages
- Integration with CI environments
- Follows good practices of Kubernetes (k8s) and containerized environments
- Does not require volumes to be mounted
- Favorable for stateless setups (not exactly this case)

### Disadvantages
- Poses security concerns for non-containerized environments
- OpSec skills needed to harden secrets from other processes running on the same
machine
- Not favorable for stateful setups (mostly this case)
- Hardening options like `hidpid=2` depend on system administrators and are not
imposable by Zallet.

## Config via on-disk file
*Definition*: available configuration parameters defined in the documentation are
set through a configuration file that is available on disk to the process or
processes involved in Z3.

### Advantages:
- File benefit from OS's user permission system which is a higher barrier to
unauthorized access.
- Encryption is handled easier.
- non-volatile, more suitable for stateful environments.

### Disadvantages:
- Requires more manual processes in terms of CI and OpSec
- can be an overkill for some type of configuration values that might change
between invocations (ie: verbosity) 

## Possible consensus on configuration methods decision:

### Create two builds of Zallet (Nuttycom's Edition)
There will be two distinct builds of Zallet for distribution purposes:
- The Default Build
  - MUST receive all of its configurable values through a config file
  - Can be run on container (provided that a config file is mounted to it)
- Container-only Build:
  - Specifically intended for containerization
  - Only distributed as prebuilt Docker Images
  - Configurable via Environment Variables
  - uses some sort of `unstable-docker-only` feature flag to compile this flavor
  of build.
#### Testing Requirements:
- CI Should test both flows
  - This would require running regtest Zebra and Zaino instances in the stack
- Minimum Setup:
 - test compiling with and without environment variables

### Mixed Approach (Yasser's Edition)
Instead of two distinct kind of builds, only maintain a single kind of build where
configuration is categorized in "non-sensitive" and "sensitive". The former are
convenience, easy-overridable environment variables. The latter are values of
secretive or business critical nature such as API keys, private keys, passwords, etc.

The values deemed non-sensitive will be allowed to be set via environment variables.
The sensitive ones will be required via configuration files.

This works for both containerized builds and normal builds.

> In Kubernetes, as I mentioned earlier, this can still be handled cleanly using
> ConfigMaps for sensitive configuration and mounting secrets as tmpfs volumes.

This approach minimizes the risk of accidental exposure while keeping deployments flexible.

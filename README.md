
[![License](https://img.shields.io/badge/license-%20%20GNU%20GPLv3%20-green)](https://github.com/cic-rwu/cic-rwu/blob/main/LICENSE)
[![Issues](https://img.shields.io/github/issues/cic-rwu/cic-rwu)](https://github.com/cic-rwu/cic-rwu/issues)


![branch main](https://img.shields.io/badge/branch-cicdaemon-green?style=flat-square)
![last commit](https://img.shields.io/github/last-commit/cic-rwu/cic-rwu/cicdaemon?display_timestamp=committer&style=flat&label=last%20commit)

# NAME

| cicdaemon -- CIC host management and compliance daemon

# SYNOPSIS

| cicdaemon < *COMMAND* > [ *OPTION* ] [ *HOST* ... ] < *SUBSYSTEM* > ...

# DESCRIPTION

**cicdaemon** is an orchestrator script for a **HOST**'s given **SUBSYSTEM**, like its *identity*, *network*, *dns*, *time*, *ssh*, and so on. It dispatches a **COMMAND** to one or more **SUBSYSTEMS**, each of which is resposible for a single concern regarding the host. **SUBSYSTEMS** are NOT specific binaries (but they can be), they are *logical parts of a host* that you want you manage.

For example, the **ssh subsystem** includes not only **ssh**(1), but **sshd**(8), as well as their respective configuration files, like */etc/ssh/sshd_config*, or even ensuring *~/.ssh* has the proper **700** permissions through **chmod**(1). See **SUBSYSTEMS** for more info.

If no **COMMAND** is specified, **COMMAND** defaults to **show** or **ls**, depending on whether a **HOST** is provided, and the **SUBSYSTEM**.

If no **HOST** is specified, **HOST** defaults to the local machine.

**cicdaemon** itself has two purposes:

- Bring newly-provisioned virtual machines to a known baseline

- Verify they stay there

The desired state is read from the inventory file at **/etc/cicdaemon/inventory.yaml**, and parsed with **yq**(1). Host details should never be hard-coded in the handlers or the dispatcher itself.

# COMMANDS

**init** [*SUBSYSTEM* ...]

Run a *SUBSYSTEM*'s init phase (if applicable). If no *SUBSYSTEM*, initialize all **SUBSYSTEMS**.

**ls** (PLANNED)

List active subsystems 

**audit** (PLANNED)

Run all **SUBSYSTEMS** in **audit** mode.

# SUBSYSTEMS

A **SUBSYSTEM** is a specific area of concern on a host, not the *binary* or *script* that implements it.
*That does not necessarily mean a subsystem can't be a specific binary*, just that subsystems should never be thought of as a binary themselves. Documentation, and even in-line comments are key here, since I want to keep this modular.

Each subsystem will be marked with one of (**audit**, **enforce**), (**audit**), or (**enforce**), which represents what the subsystem is capable of.

**audit mode** means a subsystem will report issues, but will not attempt or prompt you to reconcile those issues.

**enforce mode** means a subsystem will attempt to reconcile an issue, if it is capable of doing so.

**ssh** (**audit**, **enforce**)

# EXIT CODES
In general, this script follows the exit codes defined in `sysexits.h`,
with the exception of using *1* instead of *64* as a catch-all exit code, 
since *1* is better-known.

Additionally, like `sysexits.h`, we have defined some exit status variables
to make debugging easier

However, it should be noted these variables are NOT exported. They are used internally,
and are only displayed and handled by `ciclog`.

Outside of **0** and **1**, specific exit codes will start at **64**
See `man sysexits.h` for more info

| **0**       **EX_OK**       **Success**

**1**       Catchall for general errors, see output for more info

**64**      Bad response from **SUBSYSTEM** handler
**65**      Data format error (expected *string* but got *path*, etc.)
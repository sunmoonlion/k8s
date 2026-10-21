# fable-c1 回执（停点）Cursor 20261021-2028

P=/home/zymun/sunmoon-probe-runs/c1-20261021-2008
HEAD=7e0befc71ec82cc6a8a6d309993b66f66fef5a9f
C1=76a6334f1499ac23dbc42c1dc7530132421bf9c6
BASE=c2d0dbb5d943d4da4629c47c9ea1f74f72b6b810

## 改前 render 末尾

```
skipping: [localhost]

TASK [Copy only rendered declarations into the source tree] ********************
skipping: [localhost]

PLAY RECAP *********************************************************************
localhost                  : ok=2599 changed=180  unreachable=0    failed=0    skipped=630  rescued=0    ignored=0   
```

## 改后 render 末尾

```

TASK [Require an explicit application bind] ************************************
ok: [localhost]

TASK [Bind application paths] **************************************************
ok: [localhost]

TASK [Load application configuration and locked images] ************************
ok: [localhost]

TASK [Combine public application identity] *************************************
ok: [localhost]

TASK [Derive public rollout identity] ******************************************
ok: [localhost]

TASK [Bind generic outbound service clients] ***********************************
ok: [localhost]

TASK [Bind generic inbound service relations from each caller's own declaration] ***
ok: [localhost]

TASK [Require every inbound relation to match exactly one enabled caller client] ***
skipping: [localhost]

TASK [Validate the selected deployment and identity boundaries] ****************
[ERROR]: Task failed: Action failed: Assertion failed
Origin: /home/zymun/worktrees/fable/sunmoonun/gitops/components/app-platform/common/backend/prepare.yaml:8:3

6   ansible.builtin.include_tasks:
7     file: '{{ components_root }}/app-platform/common/backend/bind.yaml'
8 - name: Validate the selected deployment and identity boundaries
    ^ column 3

fatal: [localhost]: FAILED! => {"assertion": "cfg.private_dir == '/etc/sunmoon/applications/' + cluster_name + '/' + application_name", "changed": false, "evaluated_to": false, "msg": "Assertion failed"}

PLAY RECAP *********************************************************************
localhost                  : ok=441  changed=25   unreachable=0    failed=1    skipped=87   rescued=0    ignored=0   

make: *** [Makefile:337: components-render] Error 2
```

## config.yaml private_dir/backup_dir 字面量

```
knowfeed: private_dir='/etc/sunmoon/applications/{{ cluster_name }}/knowfeed'
knowfeed: backup_dir='{{ data_root }}/backups/applications/{{ cluster_name }}/knowfeed'
knowbase: private_dir='/etc/sunmoon/applications/{{ cluster_name }}/knowbase'
knowbase: backup_dir='{{ data_root }}/backups/applications/{{ cluster_name }}/knowbase'
tpl: private_dir='/etc/sunmoon/applications/{{ cluster_name }}/tpl'
tpl: backup_dir='{{ data_root }}/backups/applications/{{ cluster_name }}/tpl'
knowbench: private_dir='/etc/sunmoon/applications/{{ cluster_name }}/knowbench'
knowbench: backup_dir='{{ data_root }}/backups/applications/{{ cluster_name }}/knowbench'
knowlab: private_dir='/etc/sunmoon/applications/{{ cluster_name }}/knowlab'
knowlab: backup_dir='{{ data_root }}/backups/applications/{{ cluster_name }}/knowlab'
knowmart: private_dir='/etc/sunmoon/applications/{{ cluster_name }}/knowmart'
knowmart: backup_dir='{{ data_root }}/backups/applications/{{ cluster_name }}/knowmart'
```

## 卡命令补丁

- make services-chart before components-render (both sides)
- symlink sibling app repos under $P/ for temp worktree

## 结论

改前 failed=0；改后 failed=1（private_dir 断言）；三项 IDENTICAL 与第四节未跑。停点页：docs/process/switch-test/inbox/fable/2026-10-21-fable-c1-after-render-assert.md
卡仍在 inbox/cursor/。

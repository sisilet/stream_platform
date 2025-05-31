# Ansible Templates

This directory contains Jinja2 templates used by the Ansible playbooks.

## Available Templates

### `obs-scene-config.json.j2`
OBS Studio scene configuration template for Windows VMs running language mixers.

**Used by:** `ansible/playbooks/virtual-machines.yml`

**Variables:**
- `mixer_language`: The language code for this mixer (e.g., "original", "language-a")
- `audio_channels`: Audio channel mapping (e.g., "0,1", "2,3")
- `youtube_key`: YouTube RTMP stream key
- `relay_ip`: IP address of the SRT relay container
- `splitter_ip`: IP address of the slide splitter container

**Output:** JSON configuration file for OBS Studio scenes

## Template Usage

Templates are processed by Ansible's `template` or `win_template` modules and deployed to target hosts with variable substitution.

Example usage in playbook:
```yaml
- name: Configure OBS scenes
  win_template:
    src: obs-scene-config.json.j2
    dest: "C:\\Users\\{{ vm_admin_username }}\\AppData\\Roaming\\obs-studio\\basic\\scenes\\{{ item.language }}.json"
  vars:
    mixer_language: "{{ item.language }}"
    youtube_key: "{{ youtube_keys_list[ansible_loop.index0] }}"
``` 

# Pi-Puck Hacking Remnants

A loose collection of scripts, bits and bobs for hacking on Pi-Pucks.

## Usage

```bash
# Install ansible required roles
ansible-galaxy install -r ./requirements.yml
# Print out available just recipes, these are linked up to the rest of the repo
just --list
```

## Notes

- With our current images, the `i2c` channels we want seem to be:
  - `12` for the epuck hardware
  - `11` for the pi-puck hardware

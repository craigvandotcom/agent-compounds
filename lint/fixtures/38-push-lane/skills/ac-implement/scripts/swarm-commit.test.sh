#!/usr/bin/env bash
# Fixture stand-in for a proof harness — excluded by the *.test.sh glob even though it
# drives a real `git push` against a real bare remote, which is what a harness is FOR.
git push origin main

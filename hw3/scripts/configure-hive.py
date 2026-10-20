#!/usr/bin/env python3
import grp
import os
from pathlib import Path
import secrets
import subprocess
import xml.etree.ElementTree as ET


def psql(sql):
    return subprocess.check_output(
        ["sudo", "-u", "postgres", "psql", "-X", "-v", "ON_ERROR_STOP=1", "-At"],
        input=sql, text=True
    ).strip()


path = Path("/etc/hive/metastore/hive-site.xml")
password = secrets.token_hex(32)
if path.exists():
    for prop in ET.parse(path).getroot().findall("property"):
        if prop.findtext("name") == "javax.jdo.option.ConnectionPassword":
            password = prop.findtext("value")
assert len(password) == 64 and all(c in "0123456789abcdef" for c in password)

tree = ET.parse("config/hive-site.xml")
for prop in tree.getroot().findall("property"):
    if prop.findtext("name") == "javax.jdo.option.ConnectionPassword":
        prop.find("value").text = password
with os.fdopen(os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o640), "wb") as f:
    tree.write(f, encoding="UTF-8", xml_declaration=True)
os.chown(path, 0, grp.getgrnam("hive").gr_gid)

if psql("SELECT 1 FROM pg_roles WHERE rolname='hive';") != "1":
    psql(f"CREATE ROLE hive LOGIN PASSWORD '{password}';")
if psql("SELECT 1 FROM pg_database WHERE datname='hive_metastore';") != "1":
    psql("CREATE DATABASE hive_metastore OWNER hive;")

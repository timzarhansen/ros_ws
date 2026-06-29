# ROS 2 Networking (macOS Docker Desktop)

The container runs a Fast DDS discovery server on UDP `11811` so that ROS 2
nodes inside the container can be reached from other machines on the LAN
(e.g. a robot) despite macOS Docker Desktop running containers inside a
hidden Linux VM with NAT.

## How it works

* `fastdds discovery` starts as a background process inside the container,
  listening on `0.0.0.0:11811`.
* Every ROS 2 node in the container has:
  ```
  ROS_DISCOVERY_SERVER=127.0.0.1:11811
  FASTRTPS_DEFAULT_PROFILES_FILE=/etc/ros2/fastdds.xml
  ```
  so it registers with the in-container server instead of using multicast.
* Docker Desktop forwards UDP `11811` from the Mac's LAN IP into the
  container via the `ports: "11811:11811/udp"` mapping.

## One-time setup (Mac host)

1. Open Docker Desktop → **Settings** → **Resources** → **Network**.
2. Enable **"Allow incoming UDP ports"** (this opens the VM firewall for the
   `11811` port mapping).
3. Find the Mac's LAN IP:
   ```bash
   ipconfig getifaddr en0   # Wi-Fi
   # or
   ipconfig getifaddr en1   # Ethernet
   ```

## Using it

### From a robot / peer machine on the LAN

Set these environment variables on the external machine (replace
`<mac-lan-ip>` with the address from step 3 above):

```bash
export ROS_DISCOVERY_SERVER=10.60.41.52:11811
export ROS_DOMAIN_ID=161
```

Then run any `ros2` CLI or node — it will discover topics from inside the
container as if they were local.

### From the Mac host itself

```bash
export ROS_DISCOVERY_SERVER=localhost:11811
export ROS_DOMAIN_ID=161
```

Host-side tools (Foxglove Studio, `ros2 topic list`, etc.) will see
container topics without any extra configuration.

## Testing

Rebuild and reopen the devcontainer so the changes take effect. Then
verify inside the container:

### Step 1: confirm the discovery server is running

```bash
docker exec -it <container-name> bash
# inside the container:
ps aux | grep fastdds
# Should show: fastdds discovery -i 0 -l 0.0.0.0 -p 11811
```

### Step 2: test with talker/listener inside the container

```bash
# Terminal 1:
source /opt/ros/jazzy/setup.bash
source /home/tim-external/ros_ws/install/setup.bash
ros2 run demo_nodes_cpp talker --ros-args -r /chatter:=/test_lan

# Terminal 2:
source /opt/ros/jazzy/setup.bash
source /home/tim-external/ros_ws/install/setup.bash
ros2 topic echo /test_lan
# Should see messages printed.
```

### Step 3: test from the Mac host

```bash
export ROS_DISCOVERY_SERVER=localhost:11811
export ROS_DOMAIN_ID=161
ros2 topic list
# Should show /test_lan and other container topics
ros2 topic echo /test_lan
# Should receive messages from the talker inside the container
```

### Step 4: test from the robot / peer on the LAN

On the external machine:

```bash
export ROS_DISCOVERY_SERVER=<mac-lan-ip>:11811
export ROS_DOMAIN_ID=161
ros2 topic list
# Should show /test_lan and other container topics
ros2 topic echo /test_lan
# Should receive messages from the talker inside the container
```

## Troubleshooting

* **`ros2 topic list` is empty** — verify the discovery server is running:
  ```bash
  docker exec <container-name> ps aux | grep fastdds
  ```
* **Robot cannot connect** — check that the Mac's firewall allows incoming
  UDP on port 11811 (System Settings → Network → Firewall).
* **Wrong `ROS_DOMAIN_ID`** — both sides must use `161` (or whatever you set).
* **Port conflict** — if something else uses UDP 11811, change the port in
  `docker-compose.yml`, `entrypoint.sh`, and `fastdds.xml` (all three places).

## Current LLM State (2026-06-26)

### Issue
Talker/listener inside container couldn't communicate. `ros2 topic list` was empty, `ps aux | grep fastdds` showed no process, and XML parser errors appeared:
```
Error opening '/etc/ros2/fastdds.xml' -> Function loadXML
```

### Root Cause
1. `docker-compose.yml` line 35 mounted `./.devcontainer/ros2/fastdds.xml` as a volume, but this resolved to a macOS host path (`/Users/timhansen/Documents/ros_ws/...`) that doesn't exist inside the container. Docker Desktop couldn't find it, so `/etc/ros2/fastdds.xml` was missing.
2. `entrypoint.sh` line 31 starts `fastdds discovery` in the background, but it crashes silently because the XML config is missing.
3. Without the discovery server running, nodes using `ROS_DISCOVERY_SERVER=127.0.0.1:11811` can't discover each other.

### Fix Applied
1. **`DockerfileBaseARM`** — Added `COPY .devcontainer/ros2/fastdds.xml /etc/ros2/fastdds.xml` to bake the XML into the image.
2. **`docker-compose.yml`** — Commented out the broken volume mount for `fastdds.xml` (line 35).
3. **Rebuild required** — `docker compose build` then reopen devcontainer.

### Verification Steps After Rebuild
```bash
docker exec <container-name> ps aux | grep fastdds
# Should show: fastdds discovery -i 0 -l 0.0.0.0 -p 11811
```

Then test talker/listener in separate terminals inside the container.

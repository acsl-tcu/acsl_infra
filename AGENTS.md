# Repository Guidelines

## Project Structure & Module Organization
- `0_host_commands/`: host setup scripts (systemd, project launch, image helpers).
- `1_launcher/`: container entry/launch helpers (e.g., build and startup scripts).
- `2_ros_packages/`: ROS 2 packages; currently `acsl_interfaces/` for custom messages/services.
- `3_dockerfiles/`: Dockerfile definitions for base/build images.
- `4_docker/`: docker-compose configs and common container scripts.
- `hardware_setup/`, `rules/`, `docs/`: hardware setup docs, udev rules, and site/docs.

## Build, Test, and Development Commands
- Build inside the container workspace:
  - `1_launcher/launch_build.sh [packages...]` runs `colcon build` with `--symlink-install`.
  - `4_docker/common/scripts/rbuild` runs `colcon build` with a clean CMake cache.
- Start a project container (from host):
  - `docker compose --env-file <envfile> up common -d` from `4_docker/`.
- Common debug helpers (host scripts are under `0_host_commands/scripts/`); see `README.md` for `dps`, `dlogs`, and `dup`.

## Coding Style & Naming Conventions
- ROS 2 conventions: keep package layout standard (`package.xml`, `CMakeLists.txt`, `msg/`, `srv/`).
- Message/service files use PascalCase (e.g., `msg/Heartbeat.msg`, `srv/IsReady.srv`).
- Prefer descriptive, lowercase-with-underscores for script names (e.g., `launch_build.sh`).
- Follow existing formatting in `CMakeLists.txt` and ROS interface files; avoid reformatting unrelated lines.

## Testing Guidelines
- `acsl_interfaces` enables `ament_lint_auto` under `BUILD_TESTING` in `2_ros_packages/acsl_interfaces/CMakeLists.txt`.
- If you add tests or lint checks, run them in the ROS 2 workspace with `colcon test` and review results with `colcon test-result`.

## Commit & Pull Request Guidelines
- Commit messages in history are short and direct (e.g., `Update launch_build.sh`), so keep subjects concise and imperative.
- PRs should describe the change, link the related issue or project context, and note how you verified it (commands, logs, or screenshots when UI/docs change).

## Configuration & Environment Tips
- Most development assumes a Docker-based ROS 2 workspace (`/root/ros2_ws` in container) bound to this repo.
- Keep project-specific environment variables (e.g., `PROJECT`, `ROS_DOMAIN_ID`) in the relevant env files or launch scripts.

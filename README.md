# Docker Image Tool

This script provides a graphical user interface (GUI) for building and pushing Docker images. It uses Windows Forms to create a form that allows you to enter an image name and perform the necessary Docker steps.

## Prerequisites

- PowerShell version 3.0 or later
- Docker installed and accessible from PowerShell

## Usage

1. Run docker_image_tool.exe
2. The Docker Image Tool window will appear.
3. Enter the image name in the provided text box.
4. Click the "Build and Push Image" button to start the Docker steps.
5. The script will perform the following steps:
  Pull the original image using the provided image name.
  Build a new image with the provided Dockerfile and image name.
  Tag the new image with the specified registry.
  Push the tagged image to the registry.
  
  If any step fails, an error message will be displayed in the window.
  If all steps are successful, a success message will be shown.

XML Configuration
The script expects a configuration file named "config.xml" in the same directory as the script. The XML file should have the following structure:

<config>
  <image>
    <PROJECT>Project Name</PROJECT>
    <REGISTRY>Registry Name</REGISTRY>
  </image>
</config>


Make sure to replace "Project Name" and "Registry Name" with your actual project and registry names.

Notes :-

This script uses the Docker command-line tool to interact with Docker. Ensure that Docker is installed and accessible from PowerShell before running this script.
The progress bar shows the progress of the Docker steps. It will be hidden if there are no Docker operations in progress.
If an error occurs during the Docker steps, the error message will be displayed in the error label.

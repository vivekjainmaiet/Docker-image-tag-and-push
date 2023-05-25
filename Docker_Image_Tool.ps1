Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Xml

# Get the directory path of the script
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
# Set the XML file path relative to the script directory
$xmlFilePath = Join-Path -Path $scriptDirectory -ChildPath "images.xml"


# Create a form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Docker Image Tool"
$form.Size = New-Object System.Drawing.Size(500, 250)
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.StartPosition = "CenterScreen"

# Create a label for the image name input
$label = New-Object System.Windows.Forms.Label
$label.Text = "Select the image name:"
$label.Location = New-Object System.Drawing.Point(10, 20)
$label.AutoSize = $true
$form.Controls.Add($label)

# Create a dropdown list for the image names from the Harbor registry
$dropdown = New-Object System.Windows.Forms.ComboBox
$dropdown.Location = New-Object System.Drawing.Point(10, 50)
$dropdown.Size = New-Object System.Drawing.Size(280, 20)

# Read the XML file
$xml = [System.Xml.XmlDocument](Get-Content $xmlFilePath)

# Get the CAPTION and registry name from the XML nodes
$captionNodes = $xml.SelectNodes("//CAPTION")
$registryNodes = $xml.SelectNodes("//REGISTRY")

foreach ($captionNode in $captionNodes) {
    $imageCaption = $captionNode.InnerText
    foreach ($registryNode in $registryNodes) {
        $registryName = $registryNode.InnerText
        $dropdown.Items.Add("$imageCaption/$IMAGE_NAME ($registryName)")
    }
}

$form.Controls.Add($dropdown)

# Create a button to perform the Docker steps
$button = New-Object System.Windows.Forms.Button
$button.Text = "Build and Push Image"
$button.Location = New-Object System.Drawing.Point(10, 80)
$button.Size = New-Object System.Drawing.Size(150, 30)
$form.Controls.Add($button)

# Create a progress bar
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(10, 120)
$progressBar.Size = New-Object System.Drawing.Size(280, 20)
$progressBar.Style = "Continuous"
$progressBar.Minimum = 0
$progressBar.Maximum = 100
$progressBar.Visible = $false
$form.Controls.Add($progressBar)

# Create an error label
$errorLabel = New-Object System.Windows.Forms.Label
$errorLabel.ForeColor = "Red"
$errorLabel.Location = New-Object System.Drawing.Point(10, 150)
$errorLabel.AutoSize = $true
$errorLabel.Visible = $false
$form.Controls.Add($errorLabel)

# Function to handle the button click event
$button.Add_Click({
    $IMAGE_NAME = $dropdown.SelectedItem
    $NEW_IMAGE_NAME = "$imageCaption/$IMAGE_NAME"
    $HARBOR_REGISTRY = $registryName

    # Show progress bar and hide error label
    $progressBar.Visible = $true
    $errorLabel.Visible = $false

    try {
        # Pull the original image
        $pull_output = docker pull $IMAGE_NAME 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to pull the original image.`n$pull_output"
        }

        $progressBar.Value = 25

        # Build the new image with the provided Dockerfile
        $build_output = docker build -t $NEW_IMAGE_NAME --build-arg IMAGE_NAME=$IMAGE_NAME -f ./DockerFile . 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to build the new image.`n$build_output"
        }

        $progressBar.Value = 50

        # Tag the new image with the Harbor registry
        $tagged_image = "$HARBOR_REGISTRY/$NEW_IMAGE_NAME"
        docker tag $NEW_IMAGE_NAME $tagged_image

        $progressBar.Value = 75

        # Push the tagged image to the Harbor registry
        $push_output = docker push $tagged_image 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to push the tagged image.`n$push_output"
        }

        $progressBar.Value = 100

        # Show success message
        [System.Windows.Forms.MessageBox]::Show("Image build and push completed.", "Success")
    }
    catch {
        # Hide progress bar and show error label
        $progressBar.Visible = $false
        $errorLabel.Text = "Error: $_"
        $errorLabel.Visible = $true
    }
})

# Start the form
$form.ShowDialog()
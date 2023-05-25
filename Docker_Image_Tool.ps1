Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Xml

# Set the XML file path relative to the script directory
$xmlFilePath = "./config.xml"

# Create a form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Docker Image Tool"
$form.Size = New-Object System.Drawing.Size(500, 300)
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.StartPosition = "CenterScreen"

# Create a label for the processing type selection
$labelProcessingType = New-Object System.Windows.Forms.Label
$labelProcessingType.Text = "Select processing type:"
$labelProcessingType.Location = New-Object System.Drawing.Point(10, 20)
$labelProcessingType.AutoSize = $true
$form.Controls.Add($labelProcessingType)

# Create a radio button for single image processing
$radioSingle = New-Object System.Windows.Forms.RadioButton
$radioSingle.Text = "Single"
$radioSingle.Location = New-Object System.Drawing.Point(10, 50)
$radioSingle.AutoSize = $true
$radioSingle.Checked = $true
$form.Controls.Add($radioSingle)

# Create a radio button for bulk processing
$radioBulk = New-Object System.Windows.Forms.RadioButton
$radioBulk.Text = "Bulk"
$radioBulk.Location = New-Object System.Drawing.Point(10, 80)
$radioBulk.AutoSize = $true
$form.Controls.Add($radioBulk)

# Create a label for the image name input
$labelImageName = New-Object System.Windows.Forms.Label
$labelImageName.Text = "Enter the image name:"
$labelImageName.Location = New-Object System.Drawing.Point(30, 120)
$labelImageName.AutoSize = $true
$form.Controls.Add($labelImageName)

# Create a text box for the image name input
$textBoxImageName = New-Object System.Windows.Forms.TextBox
$textBoxImageName.Location = New-Object System.Drawing.Point(30, 150)
$textBoxImageName.Size = New-Object System.Drawing.Size(280, 20)
$form.Controls.Add($textBoxImageName)

# Create a button to browse for a text file for bulk processing
$buttonBrowse = New-Object System.Windows.Forms.Button
$buttonBrowse.Text = "Browse"
$buttonBrowse.Location = New-Object System.Drawing.Point(320, 150)
$buttonBrowse.Size = New-Object System.Drawing.Size(75, 23)
$buttonBrowse.Enabled = $false
$form.Controls.Add($buttonBrowse)

# Function to handle the radio button selection
$radioSingle.Add_CheckedChanged({
    if ($radioSingle.Checked) {
        $textBoxImageName.Enabled = $true
        $buttonBrowse.Enabled = $false
    }
})

$radioBulk.Add_CheckedChanged({
    if ($radioBulk.Checked) {
        $textBoxImageName.Enabled = $false
        $buttonBrowse.Enabled = $true
    }
})

# Function to handle the button click event for browsing
$buttonBrowse.Add_Click({
    $filePath = ShowOpenFileDialog
    if (![string]::IsNullOrWhiteSpace($filePath)) {
        $textBoxImageName.Text = $filePath
    }
})

# Create a button to perform the Docker steps
$button = New-Object System.Windows.Forms.Button
$button.Text = "Build and Push Image"
$button.Location = New-Object System.Drawing.Point(10, 190)
$button.Size = New-Object System.Drawing.Size(150, 30)
$form.Controls.Add($button)

# Create a progress bar
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(10, 230)
$progressBar.Size = New-Object System.Drawing.Size(280, 20)
$progressBar.Style = "Continuous"
$progressBar.Minimum = 0
$progressBar.Maximum = 100
$progressBar.Visible = $false
$form.Controls.Add($progressBar)

# Create an error label
$errorLabel = New-Object System.Windows.Forms.Label
$errorLabel.ForeColor = "Red"
$errorLabel.Location = New-Object System.Drawing.Point(10, 260)
$errorLabel.AutoSize = $true
$errorLabel.Visible = $false
$form.Controls.Add($errorLabel)

# Function to handle the button click event for processing
$button.Add_Click({
    $progressBar.Value = 0
    $errorLabel.Visible = $false

    try {
        if ($radioSingle.Checked) {
            $IMAGE_NAME = $textBoxImageName.Text
            ProcessSingleImage $IMAGE_NAME
        } elseif ($radioBulk.Checked) {
            $filePath = $textBoxImageName.Text
            if (![string]::IsNullOrWhiteSpace($filePath)) {
                $imageNames = GetImageNamesFromFile $filePath
                if ($imageNames.Count -gt 0) {
                    foreach ($imageName in $imageNames) {
                        ProcessSingleImage $imageName
                    }
                } else {
                    throw "No image names found in the selected file."
                }
            }
        }
    } catch {
        $progressBar.Visible = $false
        $errorLabel.Text = "Error: $_"
        $errorLabel.Visible = $true
        [System.Windows.Forms.MessageBox]::Show("Error: $_", "Error")
    }
})

# Function to process a single image
function ProcessSingleImage($imageName) {
    $xml = [xml](Get-Content $xmlFilePath)

    $projectName = $xml.SelectNodes("//PROJECT").InnerText
    $registryName = $xml.SelectNodes("//REGISTRY").InnerText

    $NEW_IMAGE_NAME = "$projectName/$imageName"
    $HARBOR_REGISTRY = $registryName

    $progressBar.Visible = $true

    # Pull the original image
    $pull_output = docker pull $imageName 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to pull the original image.`n$pull_output"
    }

    $progressBar.Value = 25

    # Build the new image with the provided Dockerfile
    $build_output = docker build -t $NEW_IMAGE_NAME --build-arg IMAGE_NAME=$imageName -f ./DockerFile . 2>&1
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
    [System.Windows.Forms.MessageBox]::Show("Image build and push completed for $imageName.", "Success")
}
function GetImageNamesFromFile($filePath) {
    try {
        $imageNames = Get-Content $filePath
        return $imageNames
    } catch {
        throw "Failed to read image names from the file: $_"
    }
}


# Function to show the open file dialog and return the selected file path
function ShowOpenFileDialog() {
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Title = "Select Image Names File"
    $openFileDialog.Filter = "Text Files (*.txt)|*.txt"
    $openFileDialog.InitialDirectory = [Environment]::GetFolderPath("MyDocuments")
    $openFileDialog.CheckFileExists = $true
    $openFileDialog.CheckPathExists = $true
    $openFileDialog.Multiselect = $false

    $dialogResult = $openFileDialog.ShowDialog()

    if ($dialogResult -eq [System.Windows.Forms.DialogResult]::OK) {
        return $openFileDialog.FileName
    }

    return $null
}

# Start the form
$result = $form.ShowDialog()

# Check the result and perform further actions if needed
if ($result -eq [System.Windows.Forms.DialogResult]::Cancel) {
    exit
}
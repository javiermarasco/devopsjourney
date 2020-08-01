FROM ubuntu:18.04 as baseimage

# Install Powershell in the image
RUN apt-get update 
RUN apt-get install -y wget
RUN wget -q https://packages.microsoft.com/config/ubuntu/18.04/packages-microsoft-prod.deb
RUN dpkg -i packages-microsoft-prod.deb
RUN apt-get update
RUN apt-get install -y software-properties-common
# RUN add-apt-repository universe - Not needed
RUN apt-get install -y powershell

# Install Azure powershell module in the image

RUN pwsh -Command Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted 
RUN pwsh -Command Install-Module -Name Az -AllowClobber -Scope CurrentUser

# Install Pester 4.9.0 in the image

RUN pwsh -Command Install-Module -Name Pester -RequiredVersion 4.9.0

ENTRYPOINT ["pwsh"]

# This should go in individual images, one per resource to test
FROM ./baseimage

# Copy the test file into the container in /test folder
COPY . /test

# We need the name of the output file to publish (Only NUnit)
ARG output_file_name
ENV output_file_name=${output_file_name}

# We need the provide a configuration file with the values for the test
# each image will have it's own config file structure
ARG config_file
ENV config_file=${config_file}


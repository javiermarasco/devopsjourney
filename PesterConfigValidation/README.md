# Validation of web.config keys with pester

## Needed parameters
- TemporalPath : Where the downloaded web.config file will be stored for processing, this file is then deleted.
- SubscriptionId : Id of the subscription where you will be checking for App Services configurations
- TenantId : Tenant Id or Directory Id where your subscription is deployed
- AppServiceToLook : The name of the App Service you will be checking, if this is not specified, all the App Services in the subscription will be checked.
- ValidConfig : Path to your json configuration file (The format of the file needs to be the same as the ConfigFile.json in this folder)

This script will check that the App Service you are checking contains the keys and values specified in the ConfigFile.json and also will 
validate that there are no keys in the App Service that are missing in the ConfigFile.json file (this will means you have keys in your
App Service that are missing a configuration)
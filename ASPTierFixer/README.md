# This script will help you move away your resources and re create the resource group with a dummy App Service Plan in PremiumV2 tier, then it will move your resources back to this newly created resource group and will delete the temporal resource group.

# Please be aware that the temporal App Service Plan will not be deleted, you need to delete it yourself after deploying your real App Service Plans.

# Parameters needed are:

# SubscriptionId where the resource group is located
# Resource Group Name that contains the App Service Plans with the problems.
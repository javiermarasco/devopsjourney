# ASPTierFixer

This script will help you move away your resources and re create the resource group with a dummy App Service Plan in PremiumV2 tier, then it will move your resources back to this newly created resource group and will delete the temporal resource group.

## Considerations

Please be aware that the temporal App Service Plan will not be deleted, you need to delete it yourself after deploying your real App Service Plans.

The temporal App Service Plan created is of tier PremiumV2 (expensive) and is like that to ensure you get the higher hardware tier possible so in the future you can scale up.

You don't need to deploy your App Service Plans as PremiumV2, they will land in the same webspace as the temporal App Service Plan created by this script (as long as they share resource group and location of the temporal App Service Plan).

## Parameters needed are:

* SubscriptionId where the resource group is located
* Resource Group Name that contains the App Service Plans with the problems.

# Project

Use this script to convert a Microsoft CQD building mapping exported file (TSV, CSV, etc.) to a Microsoft eCDN management console supported subnet mapping format.

## Project files

- Convert-BuildingMappingToEcdnSubnetMapping.ps1
- country_codes.ps1

## Usage

``` PowerShell
.\Convert-BuildingMappingToEcdnSubnetMapping.ps1 .\cqd_file-original.tsv -CountryCodesMapping (.\country_codes.ps1) -OutFilePath .\subnet-mapping.csv
```

Where `cqd_file-original.tsv` is your exported building mapping file, and `subnet-mapping.csv` is the Microsoft eCDN compatible subnet mapping file.

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft trademarks or logos is subject to and must follow [Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/legal/intellectualproperty/trademarks/usage/general). Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship. Any use of third-party trademarks or logos are subject to those third-party's policies.

# time-transfer-tools
Tools for analysing time-transfer data, including CGGTTS and RINEX observation files.
CGGTTS V1 and V2E files can be read.
RINEX versions 2.xx and 3.xx are supported.
Includes functions for matching observations between two files and calculating
averaged differences at each measurement time.

MATLAB classes and functions
----------------------------

|     |  Classes   |
| ---- | -----|
|CGGTTS.m          |  Read and manipulate CGGTTS files |
|RINEXobs.m        |  DEPRECATED Run away!|
|RINEXOBaseClass.m |  Base class for RINEX observation data |
|RINEX2O.m         |  Read and manipulate RINEX v2.xx files |
|RINEX3O.m         |  Read and manipulate RINEX v3.xx files |
|SatSysObs.m       |  Class for Satellite System data - used by RINEX2O and RINEX3O |


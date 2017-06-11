classdef RINEXOBaseClass < matlab.mixin.Copyable
% RINEXOBASECLASS - a class for reading RINEX3 observation files
% Usage:
%     Sub-class it.
%
% Known bugs: 
%
% RINEXOBASECLASS Properties:
%   ver - RINEX version
%   observations - vector of SatSysObj
%   t - vector of measurement times 
%		obsInterval -
%   satSystems -
%
% RINEXOBASECLASS Methods:
%   hasObservation - returns whether the specified observation is present
%   obsColumn - returns the index of the data column containing the specified observation 
%   match - match measurements between two RINEX files
%   avprdiff - averaged pseudorange differences 
% 
% Tested on Septentrio v3.02 RINEX
% 

%
% Author: MJW
%

% License
% The MIT License (MIT)
% 
% Copyright (c) 2017 Michael J. Wouters
% Permission is hereby granted, free of charge, to any person obtaining a copy
% of this software and associated documentation files (the "Software"), to deal
% in the Software without restriction, including without limitation the rights
% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
% copies of the Software, and to permit persons to whom the Software is
% furnished to do so, subject to the following conditions:
% 
% The above copyright notice and this permission notice shall be included in
% all copies or substantial portions of the Software.
% 
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
% THE SOFTWARE. 
%

	properties
		majorVer,minorVer; % RINEX version
		observations;
		t;   % measurement times 
		obsInterval; % observation interval
		satSystems; % bit mask
	end
    
	properties (Constant)
		% satellite systems
		% use to eg index into observation matrix
		GPS=1;
		GLONASS=2;
		GALILEO=3;
		BEIDOU=4;
	end
   
	properties (Constant,Access=protected)
		NSV_GPS=32;
		NSV_GLONASS=32;
		NSV_BEIDOU=32;
		NSV_GALILEO=32;
		
		% bit masks for satellite systems
		BM_GPS=1;
		BM_GLONASS=2;
		BM_GALILEO=4;
		BM_BEIDOU=8;
		
	end
    
	methods (Access='public')
	
		function obj=RINEXOBaseClass.m(fname,varargin)
				
			obj.observations = SatSysObs.empty(); % helps matlab with typing
			
		end % of RINEXObs
		
		function [ok] = hasObservation(obj,satSystem,obsType)
		% Returns whether the specified observation type is available for the
		% given satellite system
			ok = false;
			for i=1:obj.observations(satSystem).nobsTypes
				if (strcmp(obj.observations(satSystem).obsTypes(i),obsType))
					ok=true;
					break;
				end
			end
		end
        
		function [col] = obsColumn(obj,satSystem,obsType)
		% Returns the column in the GNSS observation matrix
		% containing the specified observation.
		% Zero is returned if it's missing
			col =0;
			for i=1:obj.observations(satSystem).nobsTypes
				if (strcmp(obj.observations(satSystem).obsTypes(i),obsType))
					col=i;
					break;
				end
			end
		end
		
	end % of methods
end
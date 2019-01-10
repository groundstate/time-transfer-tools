classdef RINEXOBaseClass < matlab.mixin.Copyable
% RINEXOBASECLASS - a class for reading RINEX3 observation files
% Usage:
%     Sub-class it.
%
% Known bugs: 
%
% RINEXOBASECLASS Properties:
%   majorVer - RINEX major version
%   minorVer - RINEX minor version
%   observations - vector of SatSysObj
%   t - vector of measurement times (seconds relative to the beginning of the day of the first observation
%   obsInterval - observation interval, in seconds, from the header (30 s default)
%   satSystems - bit register of satellite systems in the file
%   firstObs,lastObs - time of first observation (from header) and last observation 
%   leapSeconds - number of leap seconds, from header
%   timeSystem - time system, from header
%
% RINEXOBASECLASS Methods:
%   hasObservation - returns whether the specified observation is present
%   obsColumn - returns the index of the data column containing the specified observation 
%   match - match measurements between two RINEX files
%   avPrDiff - averaged pseudorange differences (in m)
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
		firstObs,lastObs; % DateTime; NOTE that lastObs may be determined from the file
		leapSeconds; % number 
		timeSystem;
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
		NSV_BEIDOU=64;
		NSV_GALILEO=32;
		
		% bit masks for satellite systems
		BM_GPS=1;
		BM_GLONASS=2;
		BM_GALILEO=4;
		BM_BEIDOU=8;
		
	end
    
	methods (Access='public')
	
		function obj=RINEXOBaseClass(fname,varargin)
				
			obj.observations = SatSysObs.empty(); % helps matlab with typing
			obj.firstObs=datetime(1980,1,6,0,0,0); 
			obj.lastObs=datetime(1980,1,6,0,0,0); 
			obj.leapSeconds = 0;
			obj.timeSystem = RINEXOBaseClass.GPS;
			
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
		
		function [matches] = match(obj,rnx,satSystem,obsType)
		% Compares with another set of GNSS observations, and returns
		% time-matched observations for the specified constellation and 
		% observation type. 
		% The format of the matrix is [][svn][time,obs1,obs2]

		% Some inanity checks
		
			if (~obj.hasObservation(satSystem,obsType))
				error('RINEXOBaseClass:matchObservations','observation missing');
			end
					
			if (~rnx.hasObservation(satSystem,obsType))
				error('RINEXOBaseClass:matchObservations','observation missing');
			end
			
			obscol1 = obj.obsColumn(satSystem,obsType);
			obscol2 = rnx.obsColumn(satSystem,obsType);
			
			nsv=obj.observations(satSystem).nsv;
					
			% Allocate storage
			s1 = length(obj.t)-sum(isnan(obj.t));
			s2 = length(rnx.t)-sum(isnan(rnx.t));
			%fprintf('%d %d\n',s1,s2);
			s = min(s1,s2);
			matches = NaN(s,nsv,3);
					
			tj = 1;
			ti = 1;
			nmatches=0;
			while ((ti <= length(obj.t)) && (tj <= length(rnx.t)))
			
				if (rnx.t(tj) == obj.t(ti))
					nmatches=nmatches+1;
					for sv=1:nsv
						matches(nmatches,sv,1)=obj.t(ti);
						m1 = obj.observations(satSystem).obs(ti,sv,obscol1);
						m2 = rnx.observations(satSystem).obs(tj,sv,obscol2);
						matches(nmatches,sv,2)=m1;
						matches(nmatches,sv,3)=m2;
					end
					tj = tj + 1;
					ti = ti + 1;
					continue;
				end
				
				if (rnx.t(tj) < obj.t(ti))
					tj = tj + 1;
					continue;
				end
				
				if (rnx.t(tj) > obj.t(ti))
					ti = ti + 1;
					continue;
				end
					
			end % of while
			
		end % of match()
    
		function [matches] = avPrDiff(obj,rnx,satSystem,obsType)
		% Returns a vector of averaged pseudorange differences at each
		% measurement time for the specified satellite system and
		% observation type (where there are matches)
			
			% match() will check the inputs
			all = obj.match(rnx,satSystem,obsType);
	
			matches=NaN(length(all),2);
			nsv = obj.observations(satSystem).nsv;
			
			for i=1:length(all)
				sum = 0;
				ndiffs = 0;
				for sv=1:nsv
					if ((all(i,sv,2) ~= 0) && (all(i,sv,3) ~=0))
						sum = sum + all(i,sv,2) - all(i,sv,3);
						ndiffs = ndiffs+1;
					end
				end
				if (ndiffs > 0)
					matches(i,1)=all(i,1,1);
					matches(i,2)=sum/ndiffs;
				end
			end
			
			bad = isnan(matches(:,1));
			matches(bad,:)=[];
						
		end % of avPrDiff()
        
    function [svcnt] = SVCountHistory(obj,satSystem)
	% Returns a vector of SV count as a function of time
       % The observation times are for all satellite systems
       % There may not be observations for the satellite system
       % that is being counted at all times, so zero the array
       svcnt = zeros(length(obj.t),2);
       nsv = obj.observations(satSystem).nsv;
       nobs =  length(obj.observations(satSystem).obsTypes);
       for i=1:length(svcnt)
           cnt=0;
           for s=1:nsv
               for o=1:nobs
                   if (obj.observations(satSystem).obs(i,s,o) ~= 0)
                       cnt = cnt+1;
                       break
                   end
               end
           end
           svcnt(i,1)=obj.t(i);
           svcnt(i,2)=cnt;
       end
    end
    
	end % of public methods
	
    
end
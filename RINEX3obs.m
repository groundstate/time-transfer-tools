classdef RINEX3obs < matlab.mixin.Copyable
% RINEX3OBS - a class for reading RINEX3 observation files
% Usage:
%   obs=RINEXOBS3(filename,options)
%
% Options are
%   showProgress [yes,no] : shows a progress indicator, printing each hour as an hourly block is read.
% 
% Known bugs: Only reads up to 24 hrs of data - time stamp rolls over (easily fixed)
%
% RINEX3OBS Properties:
%   ver - RINEX version
%   gps - 3-D matrix of GPS measurements (time,sv no.,measurement)
%   t - vector of measurement times 
%   obsTypes - vector of observation types - the index is the data column
%   nobsTypes - number of observation types, for convenience
%
% RINEX3OBS Methods:
%   hasObservation - returns whether the specified observation is present
%   obsColumn - returns the index of the data column containing the specified observation 
%   match - match measurements between two RINEX files
%   avprdiff - averaged pseudorange differences 
% 
% Tested on Septentrio v3.02 RINEX
% 
% Examples:   
% % Load a file
% rnxo = RINEX3obs('SYDN10190.16O','showProgress','no');
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
   
	properties (Constant,Access=private)
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
	
		function obj=RINEX3obs(fname,varargin)
				
			showProgress = 0;
			obj.observations = SatSysObs.empty(); % helps matlab with typing
			
			if (rem(nargin - 1,2) ~= 0)
				error('RINEX3obs:RINEX3obs','missing option or argument');
			end 
			
			nopts = (nargin - 1)/2;
			for i=1:nopts
				if (strcmp(varargin{i*2-1},'showProgress'))
					if (strcmp(varargin{i*2},'yes'))
						showProgress=1;
					elseif (strcmp(varargin{i*2},'no'))
						showProgress=0;
					else
						error('RINEX3obs:RINEX3obs',['bad argument ',varargin{i*2}]);
					end
				else
					error('RINEX3obs:RINEX3obs',['unknown option ',varargin{i*2-1}]);
				end
			end
			
			if (~exist(fname,'file'))
				error('RINEX3obs:RINEX3obs',['unable to open ',fname]);
			end
			
			fobs=fopen(fname);
			obj.obsInterval = -1; % flags that this was not found
			
			% Parse the header
			while (~feof(fobs))
				l = fgetl(fobs);
				
				if (strfind(l,'RINEX VERSION'))
					verStr = strtrim(l(1:9));
					obj.majorVer = floor(str2double(verStr));
					obj.minorVer = str2double(verStr)-obj.majorVer;
					
					satSystem = l(41);
					if (satSystem == ' ' || (satSystem == 'G'))
						obj.satSystems = RINEX3obs.BM_GPS;
						obj.observations(RINEX3obs.GPS) = SatSysObs('GPS');
					elseif (satSystem == 'R')
						obj.satSystems = RINEX3obs.BM_GLONASS;
						obj.observations(RINEX3obs.GLONASS) = SatSysObs('GLONASS');
					elseif (satSystem == 'E')
						obj.satSystems = RINEX3obs.BM_GALILEO;
						obj.observations(RINEX3obs.GALILEO) = SatSysObs('Galileo');
					elseif (satSystem == 'C')
						obj.satSystems = RINEX3obs.BM_BEIDOU;
						obj.observations(RINEX3obs.BEIDOU) = SatSysObs('BeiDou');
					elseif (satSystem == 'M')
						obj.satSystems = bitor(RINEX3obs.BM_GLONASS,RINEX3obs.BM_GPS);
						obj.satSystems = bitor(obj.satSystems,RINEX3obs.BM_BEIDOU);
						obj.satSystems = bitor(obj.satSystems,RINEX3obs.BM_GALILEO);
						obj.observations(RINEX3obs.GPS) = SatSysObs('GPS');
						obj.observations(RINEX3obs.GLONASS) = SatSysObs('GLONASS');
						obj.observations(RINEX3obs.GALILEO) = SatSysObs('Galileo');
						obj.observations(RINEX3obs.BEIDOU) = SatSysObs('BeiDou');
					else
						error('RINEX3obs:RINExobs','satellite system is unknown');
					end
				
					continue;
				end
				
				if (strfind(l,'INTERVAL'))
					obj.obsInterval = str2double(l(1:10));
					continue;
				end
					
				if (strfind(l,'SYS / # / OBS TYP'))
					satSysCode=l(1);
					nobs = sscanf(l(4:6),'%i');
					obsl = strtrim(l(7:58));% remove leading blank as well for use with strsplit
					nlines = ceil(nobs/14); % 13 + 1 = 14 :-)
					for line=2:nlines % first one done
						nl = fgetl(fobs);
						nl = deblank(nl(7:58));
						obsl= [obsl,nl];
					end
					% fprintf('%s %i [%s]\n',satSysCode,nobs,obsl);
					tmp = strsplit(obsl);
					if (satSysCode == 'G')
						obj.observations(RINEX3obs.GPS).obsTypes = tmp;
						obj.observations(RINEX3obs.GPS).nobsTypes=nobs;
					elseif (satSysCode == 'R')
						obj.observations(RINEX3obs.GLONASS).obsTypes = tmp;
						obj.observations(RINEX3obs.GLONASS).nobsTypes= nobs;
					elseif (satSysCode == 'E')
						obj.observations(RINEX3obs.GALILEO).obsTypes = tmp;
						obj.observations(RINEX3obs.GALILEO).nobsTypes= nobs;
					elseif (satSysCode == 'C')
						obj.observations(RINEX3obs.BEIDOU).obsTypes = tmp;
						obj.observations(RINEX3obs.BEIDOU).nobsTypes= nobs;
					else
						fprintf('Ignoring %s observations\n',satSysCode);
					end
				end
					
				if (strfind(l,'END OF HEADER'))
						break;
				end
				
				% FIXME scaling factors etc
				
			end % of header parsing
			
			if (obj.obsInterval < 0)
				obj.obsInterval = 30;
				fprintf('INTERVAL not defined: assuming 30 s\n');
			end
			
			% This data structure wastes memory but is easier to
			% work with for time-transfer, where we want to match
			% observations
			% Use zeros() because this is the convention in RINEX for
			% missing data
			nobs = ceil(1.01*86400/obj.obsInterval);% extra for duplicates
			
			if (bitand(obj.satSystems,RINEX3obs.BM_GPS))
				obj.observations(RINEX3obs.GPS).allocate(nobs,RINEX3obs.NSV_GPS); 
			end
			
			if (bitand(obj.satSystems,RINEX3obs.BM_GLONASS))
				obj.observations(RINEX3obs.GLONASS).allocate(nobs,RINEX3obs.NSV_GLONASS); 
			end
			
			if (bitand(obj.satSystems,RINEX3obs.BM_GALILEO))
				obj.observations(RINEX3obs.GALILEO).allocate(nobs,RINEX3obs.NSV_GALILEO); 
			end
			
			if (bitand(obj.satSystems,RINEX3obs.BM_BEIDOU))
				obj.observations(RINEX3obs.BEIDOU).allocate(nobs,RINEX3obs.NSV_BEIDOU); 
			end
			
			% Now read the data file
			% str2double and str2num are slow so use sscanf
			
			t = NaN(nobs,1); % current observation time in seconds
			cnt = 0;
			lasthr=-1;
			
			while (~feof(fobs))
				l = fgetl(fobs);
				nsats = 0;
				
				if (l(1) == '>') % beginning of a record
					yr = sscanf(l(3:6),'%d');
					hr = sscanf(l(13:15),'%d');
					min = sscanf(l(16:18),'%d');
					sec = sscanf(l(19:29),'%d');
					cnt = cnt+1;
					t(cnt)= hr*3600 + min*60+sec; 
					nsats = sscanf(l(33:35),'%d');
					if (hr ~= lasthr && showProgress)
						fprintf('%d ',hr);
						lasthr=hr;
					end
				end
				
				if (nsats <= 0)
					error('Bad input:',l);
				end
				
				for n=1:nsats
					l=fgetl(fobs);
					% fprintf('(%i) %s\n',length(l),l);
					satSys = l(1);
					satNum = sscanf(l(2:3),'%d');
					
					if (satSys == 'G')
						isatSys = RINEX3obs.GPS;
					elseif (satSys == 'R')
						isatSys = RINEX3obs.GLONASS;
					elseif (satSys == 'E')
						isatSys = RINEX3obs.GALILEO;
					elseif (satSys == 'C')
						isatSys = RINEX3obs.BEIDOU;
					else
						continue; % skip it
					end
					
					% the line could have missing observations at the end, but no corresponding whitespace
					% so check the line length
					maxObs = ceil((length(l) - 3)/16);
					% could be extra space at the end so clamp maxObs
					if (maxObs > obj.observations(isatSys).nobsTypes)
						maxObs=obj.observations(isatSys).nobsTypes;
					end
					% fprintf('%i satnum=%i maxobs=%i %s\n',t(cnt),satNum, maxObs,l);
					for o=1:maxObs
						obs = sscanf(l((o-1)*16+1+3:o*16+3-2 ),'%f');
						if (obs)
							obj.observations(isatSys).obs(cnt,satNum,o)=obs;
						end
					end
					
				end % for n=1:nsats
					
			end  % of while (~feof(fobs))
			
			
			if (showProgress == 1)
				fprintf(' ... done\n');
			end
			
			fclose(fobs);
			
			% Clean up a bit
			obj.t = t;
			bad = isnan(obj.t);
			obj.observations(RINEX3obs.GPS).obs(bad,:,:)=[];
			obj.observations(RINEX3obs.GLONASS).obs(bad,:,:)=[];
			obj.observations(RINEX3obs.GALILEO).obs(bad,:,:)=[];
			obj.observations(RINEX3obs.BEIDOU).obs(bad,:,:)=[];
			obj.t(bad)=[];
				
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


classdef RINEX3O < RINEXOBaseClass
% RINEX3O - a class for reading RINEX3 observation files
% Usage:
%   obs=RINEX3O(filename,options)
%
% Options are
%   showProgress [yes,no] : shows a progress indicator, printing each hour as an hourly block is read.
% 
% Known bugs: Only reads up to 24 hrs of data - time stamp rolls over (easily fixed)
%
% RINEX3O Properties:
%	 See RINEXOBASECLASS
%
% RINEX3O Methods:
%	See RINEXOBASECLASS
% 
% Tested on Septentrio v3.02 RINEX
% 
% Examples:   
% % Load a file
% rnxo = RINEX3O('SYDN10190.16O','showProgress','no');
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
		
	end
    
	methods (Access='public')
	
		function obj=RINEX3O(fname,varargin)
				
			showProgress = 0;
			obj.observations = SatSysObs.empty(); % helps matlab with typing
			
			if (rem(nargin - 1,2) ~= 0)
				error('RINEX3O:RINEX3O','missing option or argument');
			end 
			
			nopts = (nargin - 1)/2;
			for i=1:nopts
				if (strcmp(varargin{i*2-1},'showProgress'))
					if (strcmp(varargin{i*2},'yes'))
						showProgress=1;
					elseif (strcmp(varargin{i*2},'no'))
						showProgress=0;
					else
						error('RINEX3O:RINEX3O',['bad argument ',varargin{i*2}]);
					end
				else
					error('RINEX3O:RINEX3O',['unknown option ',varargin{i*2-1}]);
				end
			end
			
			if (~exist(fname,'file'))
				error('RINEX3O:RINEX3O',['unable to open ',fname]);
			end
			
			fobs=fopen(fname);
			obj.obsInterval = -1; % flags that this was not found
			tref = 0; % POSIX time of start of day
			
			obj.observations(RINEXOBaseClass.GPS) = SatSysObs('GPS',RINEXOBaseClass.NSV_GPS);
			obj.observations(RINEXOBaseClass.GLONASS) = SatSysObs('GLONASS',RINEXOBaseClass.NSV_GLONASS);
			obj.observations(RINEXOBaseClass.GALILEO) = SatSysObs('Galileo',RINEXOBaseClass.NSV_GALILEO);
			obj.observations(RINEXOBaseClass.BEIDOU) = SatSysObs('BeiDou',RINEXOBaseClass.NSV_BEIDOU);
			
			% Parse the header
			while (~feof(fobs))
				l = fgetl(fobs);
				
				if (strfind(l,'RINEX VERSION'))
					verStr = strtrim(l(1:9));
					obj.majorVer = floor(str2double(verStr));
					obj.minorVer = str2double(verStr)-obj.majorVer;
					if (obj.majorVer ~= 3)
						error('RINEX3O:RINEX3O','Not RINEX 3.xx format');
					end
					satSystem = l(41);
					if (satSystem == ' ' || (satSystem == 'G'))
						obj.satSystems = RINEXOBaseClass.BM_GPS;
						obj.timeSystem = RINEXOBaseClass.GPS; % default for pure GPS
					elseif (satSystem == 'R')
						obj.satSystems = RINEXOBaseClass.BM_GLONASS;
						obj.timeSystem = RINEXOBaseClass.GLONASS;
					elseif (satSystem == 'E')
						obj.satSystems = RINEXOBaseClass.BM_GALILEO;
						obj.timeSystem = RINEXOBaseClass.GALILEO;
					elseif (satSystem == 'C')
						obj.satSystems = RINEXOBaseClass.BM_BEIDOU;
						obj.timeSystem = RINEXOBaseClass.BEIDOU;
					elseif (satSystem == 'M')
						obj.satSystems = bitor(RINEXOBaseClass.BM_GLONASS,RINEXOBaseClass.BM_GPS);
						obj.satSystems = bitor(obj.satSystems,RINEXOBaseClass.BM_BEIDOU);
						obj.satSystems = bitor(obj.satSystems,RINEXOBaseClass.BM_GALILEO);
					else
						error('RINEX3O:RINEX3O','satellite system is unknown');
					end
				
					continue;
				end
					
				if (strfind(l,'INTERVAL'))
					obj.obsInterval = str2double(l(1:10));
					continue;
				end
				
				if (strfind(l,'TIME OF FIRST OBS'))
					yr = sscanf(l(1:6),'%d');
					mon = sscanf(l(7:12),'%d');
					day = sscanf(l(13:18),'%d');
					hr = sscanf(l(19:24),'%d');
					min = sscanf(l(25:30),'%d');
					sec = sscanf(l(31:43),'%f');
					obj.firstObs=datetime(yr,mon,day,hr,min,sec); % default TZ is UTC
					tref=floor(posixtime(obj.firstObs)/86400)*86400; % beginning of day
					
					timeSys=l(49:51);
					if (strcmp(timeSys,'GPS'))
						obj.timeSystem = RINEXOBaseClass.GPS;
					elseif (strcmp(timeSys,'GLO'))
						obj.timeSystem = RINEXOBaseClass.GLONASS;
					elseif (strcmp(timeSys,'GAL'))
						obj.timeSystem = RINEXOBaseClass.GALILEO;
					elseif (strcmp(timeSys,'BDT'))
						obj.timeSystem = RINEXOBaseClass.BEIDOU;
					end
						
						
					continue;
				end
				
				if (strfind(l,'LEAP SECONDS'))
					obj.leapSeconds = str2double(l(1:6));
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
						obj.observations(RINEXOBaseClass.GPS).obsTypes = tmp;
						obj.observations(RINEXOBaseClass.GPS).nobsTypes=nobs;
					elseif (satSysCode == 'R')
						obj.observations(RINEXOBaseClass.GLONASS).obsTypes = tmp;
						obj.observations(RINEXOBaseClass.GLONASS).nobsTypes= nobs;
					elseif (satSysCode == 'E')
						obj.observations(RINEXOBaseClass.GALILEO).obsTypes = tmp;
						obj.observations(RINEXOBaseClass.GALILEO).nobsTypes= nobs;
					elseif (satSysCode == 'C')
						obj.observations(RINEXOBaseClass.BEIDOU).obsTypes = tmp;
						obj.observations(RINEXOBaseClass.BEIDOU).nobsTypes= nobs;
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
			
			if (bitand(obj.satSystems,RINEXOBaseClass.BM_GPS))
				obj.observations(RINEXOBaseClass.GPS).allocate(nobs,RINEXOBaseClass.NSV_GPS); 
			end
			
			if (bitand(obj.satSystems,RINEXOBaseClass.BM_GLONASS))
				obj.observations(RINEXOBaseClass.GLONASS).allocate(nobs,RINEXOBaseClass.NSV_GLONASS); 
			end
			
			if (bitand(obj.satSystems,RINEXOBaseClass.BM_GALILEO))
				obj.observations(RINEXOBaseClass.GALILEO).allocate(nobs,RINEXOBaseClass.NSV_GALILEO); 
			end
			
			if (bitand(obj.satSystems,RINEXOBaseClass.BM_BEIDOU))
				obj.observations(RINEXOBaseClass.BEIDOU).allocate(nobs,RINEXOBaseClass.NSV_BEIDOU); 
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
					yr = sscanf(l(3:6),'%d'); % full year
					mon = sscanf(l(8:9),'%d');
					day = sscanf(l(11:12),'%d');
					hr = sscanf(l(14:15),'%d');
					min = sscanf(l(17:18),'%d');
					sec = sscanf(l(19:29),'%d');
					dt  = datetime(yr,mon,day,hr,min,sec); % default TZ is UTC
					toffset = floor((posixtime(dt) - tref)/86400)*86400.0;
					
					cnt = cnt+1;
					t(cnt)= hr*3600 + min*60+sec+toffset; 
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
						isatSys = RINEXOBaseClass.GPS;
					elseif (satSys == 'R')
						isatSys = RINEXOBaseClass.GLONASS;
					elseif (satSys == 'E')
						isatSys = RINEXOBaseClass.GALILEO;
					elseif (satSys == 'C')
						isatSys = RINEXOBaseClass.BEIDOU;
					else
						continue; % skip it
					end
					
					obj.observations(isatSys).empty=false;
					
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
			
			obj.lastObs = dt;
			
			% Clean up a bit
			obj.t = t;
			bad = isnan(obj.t);
			for ss=RINEXOBaseClass.GPS:RINEXOBaseClass.BEIDOU
				if (obj.observations(ss).empty)
					obj.observations(ss).obs=[];
				else
					obj.observations(ss).obs(bad,:,:)=[];
				end
			end
			obj.t(bad)=[];
				
		end % of RINEXObs
		
	end % of methods
end


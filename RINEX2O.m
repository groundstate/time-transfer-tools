classdef RINEX2O < RINEXOBaseClass
% RINEX2O - a class for reading RINEX observation files
% Usage:
%   obs=RINEX2O(filename,options)
%
% Options are
%   showProgress [yes,no] : shows a progress indicator, printing each hour as an hourly block is read.
%
% Supports RINEX V2 only (written to the v2.12 specification)
% 
% Known bugs: it's slow. That's why there's a progress indicator.
%
% RINEX2O Properties:
%  
% RINEX2O Methods:
% 
% Tested on Septentrio v2.11 RINEX
% 
% Examples:   
% % Load a file
% rnxo = RINEX2O('SYDN10190.16O','showProgress','no');
%
% % Get GPS P1 measurements for PRN24
% 
%
% % Match GPS P1 measurements in rnx1 and rnx2
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
	
		totalObsTypes; % total number of observation types 
		
	end
    
	methods (Access='public')
	
		function obj=RINEX2O(fname,varargin)
				
			showProgress = 0;
			obj.observations = SatSysObs.empty(); % helps matlab with typing
			
			if (rem(nargin -1,2) ~= 0)
				error('RINEX2O:RINEX2O','missing option or argument');
			end 
			
			nopts = (nargin - 1)/2;
			for i=1:nopts
				if (strcmp(varargin{i*2-1},'showProgress'))
					if (strcmp(varargin{i*2},'yes'))
						showProgress=1;
					elseif (strcmp(varargin{i*2},'no'))
						showProgress=0;
					else
						error('RINEX2O:RINEX2O',['bad argument ',varargin{i*2}]);
					end
				else
					error('RINEX2O:RINEX2O',['unknown option ',varargin{i*2-1}]);
				end
			end
				
			if (~exist(fname,'file'))
				error('RINEX2O:RINEX2O',['unable to open ',fname]);
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
						if (obj.majorVer >= 3)
							error('RINEX2O:RINEX2O','Version 2.xx only - use RINEX3O');
						end
							
						% valid types are G (or blank), R, S, E, M
						satSystem = l(41);
						if (satSystem == ' ' || (satSystem == 'G'))
							obj.satSystems = RINEXOBaseClass.BM_GPS;
							obj.observations(RINEXOBaseClass.GPS) = SatSysObs('GPS');
						elseif (satSystem == 'R')
							obj.satSystems = RINEXOBaseClass.BM_GLONASS;
							obj.observations(RINEXOBaseClass.GLONASS) = SatSysObs('GLONASS');
						elseif (satSystem == 'E')
							obj.satSystems = RINEXOBaseClass.BM_GALILEO;
							obj.observations(RINEXOBaseClass.GALILEO) = SatSysObs('Galileo');
						elseif (satSystem == 'C')
							obj.satSystems = RINEXOBaseClass.BM_BEIDOU;
							obj.observations(RINEXOBaseClass.BEIDOU) = SatSysObs('BeiDou');
						elseif (satSystem == 'M')
							obj.satSystems = bitor(RINEXOBaseClass.BM_GLONASS,RINEXOBaseClass.BM_GPS);
							obj.satSystems = bitor(obj.satSystems,RINEXOBaseClass.BM_BEIDOU);
							obj.satSystems = bitor(obj.satSystems,RINEXOBaseClass.BM_GALILEO);
							obj.observations(RINEXOBaseClass.GPS) = SatSysObs('GPS');
							obj.observations(RINEXOBaseClass.GLONASS) = SatSysObs('GLONASS');
							obj.observations(RINEXOBaseClass.GALILEO) = SatSysObs('Galileo');
							obj.observations(RINEXOBaseClass.BEIDOU) = SatSysObs('BeiDou');
						else
							error('RINEX2O:RINEX2O','satellite system is unknown');
						end
							
						continue;
						
					end
					
					if (strfind(l,'INTERVAL'))
						obj.obsInterval = str2double(l(1:10));
						continue;
					end
					
					% FIXME should check the time of first and last obs
					% and the interval
					if (strfind(l,'TYPES OF OBSERV'))
						obj.totalObsTypes = str2num(l(1:6));
						rnx2obsTypes = zeros(1,obj.totalObsTypes);
						obsl = strtrim(l(7:60));% remove leading blank as well for use with strsplit
						nlines = ceil(obj.totalObsTypes/10); 
						for line=2:nlines % first one done
							nl = fgetl(fobs);
							nl = deblank(nl(7:60));
							obsl= [obsl,nl];
						end
						tmp = strsplit(obsl);
						% RINEX 2.xx is a bit messier in that we have to sort out ourselves
						% which observation types are valid for each satellite system
						% GPS has valid frequency codes 1,A,B,2,C,5
						% GLONASS has 1,A,2,D
						% Galileo has 1,5,6,7,8
						% Beidou  has 1,2,6,7
						obj.setObservationCodes(tmp,RINEXOBaseClass.GPS,{'1','A','B','2','C','5'});
						obj.setObservationCodes(tmp,RINEXOBaseClass.GLONASS,{'1','A','2','D'});
						obj.setObservationCodes(tmp,RINEXOBaseClass.GALILEO,{'1','5','6','7','8'});
						obj.setObservationCodes(tmp,RINEXOBaseClass.BEIDOU,{'1','2','6','7'});
						
						continue;
					end
					
					if (strfind(l,'END OF HEADER'))
						break;
					end
					
			end
				
			if (obj.obsInterval < 0)
				obj.obsInterval = 30;
				fprintf('INTERVAL not defined: assuming 30 s\n');
			end
			
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
				
				% fprintf('%d %s',t,l);
				% year 2:3,month 5:6,day 8:9,hr 11:12, min 14:15,sec 16:26
				hr = sscanf(l(11:12),'%d');
				min = sscanf(l(14:15),'%d');
				sec = sscanf(l(16:26),'%d');
				cnt = cnt+1;
				t(cnt)= hr*3600 + min*60+sec; 
				nsats = sscanf(l(30:32),'%d');
				if (hr ~= lasthr && showProgress)
					fprintf('%d ',hr);
					lasthr=hr;
				end
				% fprintf('%d %d %d\n',hr,min,sec);
				% Build a string of all SVIDs for parsing
				if (nsats <=12)
					sats = l(33:(33+nsats*3-1));
				else
					sats = l(33:(33+12*3-1));
					% read continuation lines
					linestodo = ceil((nsats-12)/12);
					for line=1:linestodo
						l=fgets(fobs);
						%fprintf('%s\n',l);
						sats = strcat(sats,strtrim(l(33:end)));
					end
				end
				% fprintf('[%s]\n',sats);
				for i=1:nsats
					svid = sats(1+(i-1)*3:i*3);
					satSystem = svid(1);
					svn = sscanf(svid(2:3),'%d');
					
					% If more than 5 observations then there are
					% multiple lines to read
					obstr = '';
					nlines = ceil((obj.totalObsTypes-5)/5)+1;
					%fprintf('[%s]\n',obstr);
					for line=1:nlines;
						% there could be a whole line missing or
						% or just some measurements at the end so
						% pad it out to 80 characters
						nl = fgetl(fobs);
						newobs=sprintf('%-80s',nl);
						%  fprintf('[%s]\n',newobs);
						obstr  = [obstr,newobs]; % preserve trailing spaces
					end
							
					% fprintf('%d %d\n',linestodo,length(obstr));
					% Now parse the string
					for o=1:obj.totalObsTypes
						% fprintf('%d %s %d %s\n',cnt,svid,o,obstr(1+(o-1)*16:1+(o-1)*16+13));
						pr = sscanf(obstr(1+(o-1)*16:1+(o-1)*16+13),'%f');
						% Missing data can be flagged as zero or
						% 'blank' so the conversion can fail
						if (pr)
							if (bitand(obj.satSystems,RINEXOBaseClass.BM_GPS) && satSystem=='G')
								obj.observations(RINEX2O.GPS).obs(cnt,svn,o) = pr;
								obj.observations(RINEX2O.GPS).empty=false;
							elseif (bitand(obj.satSystems,RINEXOBaseClass.BM_GLONASS) && satSystem=='R' )
								obj.observations(RINEX2O.GLONASS).obs(cnt,svn,o) = pr;
								obj.observations(RINEX2O.GLONASS).empty=false;
							elseif (bitand(obj.satSystems,RINEXOBaseClass.BM_GALILEO) && satSystem=='E')
								obj.observations(RINEX2O.GALILEO).obs(cnt,svn,o) = pr;
								obj.observations(RINEX2O.GALILEO).empty=false;
							elseif (bitand(obj.satSystems,RINEXOBaseClass.BM_BEIDOU) && satSystem=='C')
								obj.observations(RINEX2O.BEIDOU).obs(cnt,svn,o) = pr;
								obj.observations(RINEX2O.BEIDOU).empty=false;
							end
						end
					end
					%
					% fprintf('\n');
				end
				%fprintf('%d %s\n',nsats,sats);
			end % of while 
            
			fclose(fobs);
				
			if (showProgress == 1)
				fprintf(' ... done\n');
			end
			
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
  
  methods (Access='private')
  
		function setObservationCodes(obj,obsarr,satSystem,validCodes)
			for i=1:length(obsarr)
				for j=1:length(validCodes)
					if (obsarr{1,i}(2) == validCodes{1,j})
						obj.observations(satSystem).obsTypes{1,i} = obsarr{1,i};
						break;
					end
				end
			end
			obj.observations(satSystem).nobsTypes = length(obj.observations(satSystem).obsTypes);
		end
		
  end % of private methods
   
end % of class RINEX2O


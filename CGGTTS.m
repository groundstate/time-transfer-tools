
classdef CGGTTS < matlab.mixin.Copyable
	% CGGTTS Reads and holds a sequence of CGGTTS files
	%  Usage:
	%   CGGTTS(startMJD,stopMJD,path,filestub,options)
	%     
	%   filestub is that part of the filename needed in addition to the MJD to construct a filename
  %
  %  
	%   Options:
	%   RemoveBadTracks ['yes','no']
	%   NamingConvention ['BIPM','simple'] simple is of form MJD.filestub
	%
	%   The data is in the matrix Tracks, each row of which is a single CGGTTS track and the columns are indexed by the same label as used in CGGTTS
	%   with the following caveats
	%   STTIME is converted to time-of-day in seconds
	%   SAT    is broken into two fields - SATSYS ('G','E') etc and PRN/SVN
	%          Note that SATSYS is stored as a double so you need to convert to char
	%   FRC    is stored in three columns, starting at obj.FRC, as doubles
	%
	% CGGTTS Properties:
	%
	% CGGTTS  Methods:
	%   FilterTracks(maxDSG, minTrackLength )
	%   Filter(prop, minVal, maxVal)
	%
	% Example
	%   d = CGGTTS(57800,57801,'/home/timelord/cggtts/','GMAU99','NamingConvention','BIPM');
	%
	% Author: MJW 2012-11-01
	
	% License
	%
	% The MIT License (MIT)
	%
	% Copyright (c) 2017 Michael J. Wouters
	% 
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

	properties
        
		Tracks; % vector of CGGTTS tracks 
		Version; % CGGTTS version
		Lab;
		CableDelay;
		ReferenceDelay;
		CADelay,P1Delay,P2Delay; % presumption is that this doesn't change
		BadTracks; % count of bad tracks flagged in the CGGTTS data
		DualFrequency;
        
		Sorted;
    
		% Indices into the data matrix
		% Most of these are constant 
		SATSYS; % non-standard!
    PRN,CL,MJD,STTIME,TRKL,ELV,AZTH,REFSV,SRSV,REFGPS,REFSYS;
		SRGPS,SRSYS,DSG,IOE,MDTR,SMDT,MDIO,SMDI;
		MSIO,SMSI,ISG; % dual frequency
		FR,HC,FRC; % V2E extras
		CK;
	end
  
  properties (Access='private')
		namingConvention;
  end
  
  properties (Constant,Access='private')
		BIPMname=1;
		SimpleName=2;
  end
  
	methods (Access='public')
		% Constructor
        
		function obj=CGGTTS(startMJD,stopMJD,path,filestub,varargin)
		
			removeBadTracks = 1;
			namingConvention=CGGTTS.SimpleName;
			
			% FIXME Fix up the path, if necessary
			
			if (rem(nargin - 4,2) ~= 0)
				error('CGGTTS:CGGTTS','missing option or argument');
			end 
			
			nopts = (nargin - 4)/2;
			for i=1:nopts
				a = lower(varargin{i*2});
				if (strcmp(varargin{i*2-1},'RemoveBadTracks'))
					
					if (strcmp(a,'yes'))
						removeBadTracks=1;
					elseif (strcmp(a,'no'))
						removeBadTracks=0;
					else
						error('CGGTTS:CGGTTS','bad argument %s',varargin{i*2});
					end
				elseif (strcmp(varargin{i*2-1},'NamingConvention'))
					if (strcmp(a,'bipm'))
						namingConvention=CGGTTS.BIPMname;
					elseif (strcmp(a,'simple'))
						namingConvention=CGGTTS.SimpleName;
					else
						error('CGGTTS:CGGTTS','bad argument %s',varargin{i*2});
					end
				else
						error('CGGTTS:CGGTTS','unknown option %s',varargin{i*2-1});
				end
			end
            
			obj.Tracks=[];
			trks=[];
			
			obj.Version=0;
			obj.DualFrequency=0;
			obj.CableDelay=0;
			obj.ReferenceDelay=0;
			obj.CADelay=0;
			obj.P1Delay=0;
			obj.P2Delay=0;
			obj.BadTracks=0;
			obj.Sorted=0;
				
			for mjd=startMJD:stopMJD
				if (namingConvention == CGGTTS.SimpleName)
					fname  = [path int2str(mjd) filestub];
					if (~exist(fname))
						warning('%s is missing',fname); % not critical
						continue;
					end
				elseif (namingConvention == CGGTTS.BIPMname)
					mjdDD=floor(mjd/1000); % OK for another 100 years :-)
					mjdDDD=mjd - mjdDD*1000;
					fname  = sprintf('%s%s%02d.%03d',path,filestub,mjdDD,mjdDDD);
					if (~exist(fname))
						warning('%s is missing',fname); % not critical
						continue;
					end
				end
				fh = fopen(fname);

				% obj is strictly formatted so we'll assume that's true
				% and bomb if not.
				
				% Read the header of every file, just in case there is something odd
				% Line 1 Version
				hdrline = fgets(fh);
				[mat]=regexp(hdrline,'\s*DATA\s*FORMAT\s*VERSION\s*=\s*(1|01|2E|2e)','tokens');
				if (size(mat))
					if (strcmp(mat{1},'1') || strcmp(mat{1},'01')) 
						obj.Version=1;
					elseif (strcmp(mat{1},'2E') || strcmp(mat{1},'2e')) 
						obj.Version=2;
					else
						error('Unable to determine the CGGTTS version in the input file %s',fname);
					end;
				end;
		
				% Line 2 Revision date
				hdrline = fgets(fh);
				% Line 3 Receiver
				hdrline = fgets(fh);
				% Line 4 Number of channels
				hdrline = fgets(fh);
				% Line 5 IMS
				hdrline = fgets(fh);
				% Line 6 LAB
				hdrline = fgets(fh);
				% FIXME surely you can assign within the conditional
				% expression ? How do you do this ?
				if (regexp(hdrline,'^\s*LAB\s*=\s*'))
						obj.Lab=hdrline;
				end;
				% Line 7 X
				hdrline = fgets(fh);
				% Line 8 Y
				hdrline = fgets(fh);
				% Line 9 Z
				hdrline = fgets(fh);
				% Line 10 FRAME
				hdrline = fgets(fh);
				% Line 11 COMMENTS
				hdrline = fgets(fh);
				% Line 12 INT DLY
				hdrline = fgets(fh);
				[mat]=regexp(hdrline,'INT\s+DLY\s*=\s*([+-]?\d+\.?\d*)','tokens');
				if (size(mat))
						obj.CADelay=str2double(mat{1});
				end;
				% Line 13 CAB DLY
				hdrline = fgets(fh);
				[mat]=regexp(hdrline,'CAB\s+DLY\s*=\s*([+-]?\d+\.?\d*)','tokens');
				if (size(mat))
						obj.CableDelay=str2double(mat{1});
				end;
				% Line 14 REF DLY
				hdrline = fgets(fh);
				[mat]=regexp(hdrline,'REF\s+DLY\s*=\s*([+-]?\d+\.?\d*)','tokens');
				if (size(mat))
						obj.ReferenceDelay=str2double(mat{1});
				end;
				% Line 15 REF
				hdrline = fgets(fh);
				% Line 16 CKSUM
				hdrline = fgets(fh);
				% Line 17 (blank line)
				hdrline = fgets(fh);
				
				% Line 18 (data column labels)
				hdrline = fgets(fh);
				if (regexp(hdrline,'MSIO SMSI')) % detect dual frequency
						obj.DualFrequency=1;
				end;
				% Line 19 (units)
				hdrline = fgets(fh);
        
        % We'll add an extra column to V1 CGGTTS so that indexing of interesting columns is the same for V1 and V2
        % It'll make eg sorting algorithms cleaner
        
        obj.SATSYS=1;obj.PRN=2;obj.CL=3; obj.MJD=4;obj.STTIME=5;obj.TRKL=6;obj.ELV=7;obj.AZTH=8;obj.REFSV=9;obj.SRSV=10;
				obj.REFGPS=11;obj.REFSYS=11;obj.SRGPS=12;obj.SRSYS=12;obj.DSG=13;obj.IOE=14;obj.MDTR=15;obj.SMDT=16;obj.MDIO=17;obj.SMDI=18;obj.MSIO=19;obj.SMSI=20;
				obj.ISG=21;	
				if (obj.Version==1)
					if (obj.DualFrequency == 0)
						obj.CK = 19;
					else
						obj.CK = 22;
					end
				elseif (obj.Version==2)
					if (obj.DualFrequency == 0)
						obj.FR =  19;
						obj.HC =  20;
						obj.FRC = 21; % three characters for FRC
						obj.CK =  24; 
					else
						obj.FR = 22;
						obj.HC = 23;
						obj.FRC = 24; % three characters for FRC
						obj.CK = 27;
					end
				end
				
				% Read the tracks
				% Don't use fscanf(,inf) because we scan for a character in the first field of V2E files (which then picks up the newline)
				while (~feof(fh))
					if (obj.DualFrequency == 0)
						l = fgetl(fh);
						if (obj.Version == 1)
							cctftrks = sscanf(l,  '%d %x %d %s %d %d %d %d %d %d %d %d %d %d %d %d %d %x'); % (18) +5 for HHMMSS
						else
							cctftrks = sscanf(l,'%c%d %x %d %s %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %s %x'); % (21) +1 for SAT, +5 for HHMMSS, +2 FRC
						end
					else
						if (obj.Version == 1)
							cctftrks = sscanf(l,'%d %x %d %s %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %x'); % (21) +5 for HHMMSS
						else
							cctftrks = sscanf(l,'%c%d %x %d %s %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %s %x'); % (24) +1 for SAT, +5 for HHMMSS, , +2 FRC
						end
					end
					% FIXME compute checksums and remove bad data
					trks=[trks cctftrks];
				end
				fclose(fh);
				
			end % for MJD
			trks=trks';
			
			if (length(trks)==0)
				warning('CGGTTS:CGGTTS','no data');
				return;
			end
			
			% Prepend the SATSYS column to V1 data and fill it
			if (obj.Version == 1)
	      satsys(1:length(trks))=double('G');
	      trks = [satsys' trks];
			end
			
			% Convert the HHMMSS [columns 4-9] field into decimal seconds
%  			trks(:,4)= ((trks(:,4)-48)*10 + trks(:,5)-48)*3600 + ...
%  				((trks(:,6)-48)*10 + trks(:,7)-48)* 60 + ...
%  				(trks(:,8)-48)*10 + trks(:,9)-48;
%  			trks(:,5:9)=[];
			trks(:,5)= ((trks(:,5)-48)*10 + trks(:,6)-48)*3600 + ...
				((trks(:,7)-48)*10 + trks(:,8)-48)* 60 + ...
				(trks(:,9)-48)*10 + trks(:,10)-48;
			trks(:,6:10)=[];

			% Remove any bad data
			if (removeBadTracks)
				n = size(trks,1);
				bad = 1:n;
				badcnt=0;
				for i = 1:n
					bad(i)=0;

					if ((trks(i,obj.DSG) == 9999 ))
						bad(i)=1;
						badcnt=badcnt+1;
					end

					if obj.DualFrequency==1
						% Check MSIO,SMSI,ISG for dual frequency
						if ((trks(i,obj.ISG) == 999 ) || (trks(i,obj.MSIO) == 9999 ) || (abs(trks(i,obj.SMSI)) == 999 ))
							bad(i)=1;
							badcnt=badcnt+1;
						end
					end

				end % for i = 1:n
				obj.BadTracks=badcnt;
				trks(any(bad,1),:)=[];
			end
      obj.Tracks=trks;
		end
        
		function obj = FilterTracks( obj, maxDSG, minTrackLength )
			% Applies basic filtering to CGGTTS data
			% Retain for backwards compatibility with legacy code
			obj = obj.Filter(obj.DSG, 0, maxDSG);
			obj = obj.Filter(obj.TRKL, minTrackLength, 780);
		end
       
		function obj = Filter( obj, prop, minVal, maxVal )
			% Filter on property 'prop' (one of the data columns in the CGGTTS file), retaining only data in [minVal,maxVal]
			n = size(obj.Tracks,1);
			bad = 1:n;
			for i = 1:n
				bad(i)=0;
				if ((obj.Tracks(i,prop) < minVal) || (obj.Tracks(i,prop) > maxVal))
					bad(i)=1;
				end
			end
			obj.Tracks(any(bad,1),:)=[];
		end
        
		function PlotDSG(obj,titleText)
			startMJD=obj.Tracks(1,obj.MJD);
			plot(obj.Tracks(:,obj.MJD)+obj.Tracks(:,obj.STTIME)/86400 -startMJD,obj.Tracks(:,obj.DSG)*0.1,'.');
			title(titleText);
			xlabel(['MJD - ',num2str(startMJD)]);
			ylabel('DSG (ns)');
		end
        
		function PlotVisibility(obj,titleText)
			plot(obj.Tracks(:,obj.AZTH)*0.1,obj.Tracks(:,obj.ELV)*0.1,'.');
			%polarplot(obj.Tracks(:,obj.AZTH)*0.1*pi/180.0,cos(obj.Tracks(:,obj.ELV)*0.1*pi/180.0),'o');
			title(titleText);
			xlabel('azimuth (deg)');
			ylabel('elevation (deg)');
		end
        
		function Summary(obj)
			fprintf('%s\n',obj.Lab);
			fprintf('Cable delay = %g\n', obj.CableDelay);
			fprintf('Reference delay = %g\n', obj.ReferenceDelay);
			fprintf('CA internal delay = %g\n', obj.CADelay);
			fprintf('P1 internal delay = %g\n', obj.P1Delay);
			fprintf('P2 internal delay = %g\n', obj.P2Delay);
			fprintf('Dual frequency =', obj.DualFrequency);
			fprintf('Tracks = %g, (bad = %g)\n ',size(obj.Tracks,1),obj.BadTracks);
		end
        
		function [refgps]=AverageREFSYS(obj,varargin)
		
			if (rem(nargin - 1,2) ~= 0)
				fprintf('%d\n',nargin);
				error('CGGTTS:Average','missing option or argument');
			end 
			% Calculate the averaged value of REFSYS at each 
			% observation time.
			
			satsys = 'G'; % GPS is default
			
			nopts = (nargin - 1)/2;
			for i=1:nopts
				a = lower(varargin{i*2});
				if (strcmp(varargin{i*2-1},'SatelliteSystem'))
					if (strcmp(a,'g'))
						satsys='G';
					elseif (strcmp(a,'r'))
						satsys='R'
					elseif (strcmp(a,'e'))
						satsys='E';
					end
				end
			end
			
			if (obj.Sorted == 0) % only do it once
				obj.SortSVN(); 
			end;
			
			n = size(obj.Tracks(),1);
			i=1;
			av=0;
			cnt=0;
			sampcnt=0;
			refgps=[];
			lastmjd=obj.Tracks(i,obj.MJD);
			lastst=obj.Tracks(i,obj.STTIME);
		
			while (i<=n)
				if (~(obj.Tracks(i,obj.SATSYS) == satsys))
					i=i+1;
					continue;
				end
				if (obj.Tracks(i,obj.MJD) == lastmjd && obj.Tracks(i,obj.STTIME) == lastst)
					av = av + obj.Tracks(i,obj.REFSYS);
					sampcnt=sampcnt+1;    
				else
					av =av/sampcnt;
					cnt=cnt+1;
					refgps(cnt,:) = [ lastmjd+lastst/86400.0 av ];
					av=obj.Tracks(i,obj.REFSYS);
					sampcnt=1;
						
				end
				lastmjd=obj.Tracks(i,obj.MJD);
				lastst=obj.Tracks(i,obj.STTIME);
				i=i+1;
			end
			if (sampcnt > 0)
				av =av/sampcnt; % add the last one
				cnt=cnt+1;
				refgps(cnt,:) = [lastmjd+lastst/86400.0 av];
			end
		end
        
	end % of methods
    
	methods (Access='private')
	
		function SortSVN(obj)
			% Sorts tracks by SVN within each time block
			% as defined by MJD and STTIME
			% This is to make track matching easier
			n = size(obj.Tracks(),1);
			lastmjd=obj.Tracks(1,obj.MJD);
			lastst =obj.Tracks(1,obj.STTIME);
			stStart=1;
			for i=2:n
				if (obj.Tracks(i,obj.MJD) == lastmjd && ...
					obj.Tracks(i,obj.STTIME)==lastst)
					% sort
					j=i;
					while (j > stStart)
						if (obj.Tracks(j,obj.PRN) < obj.Tracks(j-1,obj.PRN))
								tmp = obj.Tracks(j-1,:);
								obj.Tracks(j-1,:)= obj.Tracks(j,:);
								obj.Tracks(j,:)=tmp;
						else
								break;
						end
						j=j-1;
					end
				else
					lastmjd=obj.Tracks(i,obj.MJD);
					lastst=obj.Tracks(i,obj.STTIME);
					stStart=i;
					% nothing more to do
				end
			end
			obj.Sorted=1;
		end
		
	end % methods

end % class



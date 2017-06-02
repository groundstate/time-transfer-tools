
classdef CGGTTS < matlab.mixin.Copyable
	%CGGTTS Reads CGGTTS files
	%  Usage:
	%   CGGTTS(startMJD,stopMJD,path,extension,options)
	%
	%Author: MJW 2012-11-01
	%
	%CGGTTS Properties:
	%
	%CGGTTS Methods:
	%
	%License
	%
	%The MIT License (MIT)
	%
	%Copyright (c) 2017 Michael J. Wouters
	% 
	%Permission is hereby granted, free of charge, to any person obtaining a copy
	%of this software and associated documentation files (the "Software"), to deal
	%in the Software without restriction, including without limitation the rights
	%to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	%copies of the Software, and to permit persons to whom the Software is
	%furnished to do so, subject to the following conditions:
	% 
	%The above copyright notice and this permission notice shall be included in
	%all copies or substantial portions of the Software.
	% 
	%THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	%IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	%FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	%AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	%LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	%OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
	%THE SOFTWARE.

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
    
		% Indices into data matrix which depend on CGGTTS version and single/dual frequency
		GNSS; % GNSS system
		CK; % CKSUM
		FR,HC,FRC;
    
	end
    
	properties (Constant)
		% A few useful named constants
		PRN=1;
		CL=2; 
		MJD=3;
		STTIME=4;
		TRKL=5;
		ELV=6;
		AZTH=7;
		REFSV=8;
		SRSV=9;
		REFGPS=10;
		SRGPS=11;
		DSG=12;
		IOE=13;
		MDTR=14;
		SMDT=15;
		MDIO=16;
		SMDI=17;
		MSIO=18;
		SMSI=19;
		ISG=20;
		FR22=21;  % CGGTTS V2 dual frequency
		HC22=22;
		FRC22=23;
		CK22=24;
       
	end
    
	properties (Constant,Access='private')
		
		CK_V1_SF = 18; % V1 checksum
		CK_V1_DF = 99; % FIXME
		
		FR_SF = 18;
		HC_SF = 19;
		FRC_SF = 20;
		CK_V2_SF =21;
		
		FR_DF = 21;
		HC_DF = 22;
		FRC_DF = 23;
		CK_V2_DF = 24;
		
	end    
        
	methods (Access='public')
		% Constructor
        
		function obj=CGGTTS(startMJD,stopMJD,path,extension,varargin)
		
			removeBadTracks = 1;
			
			if (rem(nargin - 4,2) ~= 0)
				error('CGGTTS:CGGTTS','missing option or argument');
			end 
			
			nopts = (nargin - 4)/2;
			for i=1:nopts
				if (strcmp(varargin{i*2-1},'RemoveBadTracks'))
					if (strcmp(varargin{i*2},'yes'))
						removeBadTracks=1;
					elseif (strcmp(varargin{i*2},'no'))
						removeBadTracks=0;
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
				
				fname  = [path int2str(mjd) extension];
				if (~exist(fname))
					warning('%s is missing',fname); % not critical
					continue;
				end
				fh = fopen(fname);

				% CGGTTS is strictly formatted so we'll assume that's true
				% and bomb if not.
				
				% Read the header of every file, just in case there is something odd
				% Line 1 Version
				hdrline = fgets(fh);
				[mat]=regexp(hdrline,'\s*DATA\s*FORMAT\s*VERSION\s*=\s*(1|01|2E|2e)','tokens');
				if (size(mat))
					if (strcmp(mat{1},'1') || strcmp(mat{1},'01')) 
						obj.Version=1;
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
                
				if (obj.Version==0)
					error('Unable to determine the CGGTTS version in the input file %s',fname);
				end
                
				% Read the tracks
				if (obj.DualFrequency == 0)
					if (obj.Version == 1)
						cctftrks = fscanf(fh,'%d %x %d %s %d %d %d %d %d %d %d %d %d %d %d %d %d %x',[23 inf]); % +5 for HHMMSS
					else
						cctftrks = fscanf(fh,'%c%d %x %d %s %d %d %d %d %d %d %d %d %d %d %d %d %s %x',[27 inf]); % +1 for SAT, +5 for HHMMSS, +2 FRC
					end
				else
					if (obj.Version == 1)
						cctftrks = fscanf(fh,'%d %x %d %s %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %x',[26 inf]); % +5 for HHMMSS
					else
						cctftrks = fscanf(fh,'%c%d %x %d %s %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %s %x',[32 inf]); % +1 for SAT, +5 for HHMMSS
					end
				end
				cctftrks = cctftrks';
				trks=[trks;cctftrks];
				fclose(fh);
				% FIXME compute checksums and remove bad data
				
			end % for MJD
			
			%if (obj.Version == 1)
	    %  trks(:,CGGTTS.GNSS)='G';
			%end
			
			if (length(trks)==0)
				warning('CGGTTS:CGGTTS','no data');
				return;
			end
			
			% Convert the HHMMSS [columns 4-9] field into decimal seconds
			trks(:,4)= ((trks(:,4)-48)*10 + trks(:,5)-48)*3600 + ...
				((trks(:,6)-48)*10 + trks(:,7)-48)* 60 + ...
				(trks(:,8)-48)*10 + trks(:,9)-48;
			trks(:,5:9)=[];
            
			% Remove any bad data
			if (removeBadTracks)
				n = size(trks,1);
				bad = 1:n;
				badcnt=0;
				for i = 1:n
					bad(i)=0;

					if ((trks(i,CGGTTS.DSG) == 9999 ))
						bad(i)=1;
						badcnt=badcnt+1;
					end

					if obj.DualFrequency==1
						% Check MSIO,SMSI,ISG for dual frequency
						if ((trks(i,CGGTTS.ISG) == 999 ) || (trks(i,CGGTTS.MSIO) == 9999 ) || (abs(trks(i,CGGTTS.SMSI)) == 999 ))
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
			obj = obj.Filter(CGGTTS.DSG, 0, maxDSG);
			obj = obj.Filter(CGGTTS.TRKL, minTrackLength, 780);
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
			plot(obj.Tracks(:,CGGTTS.MJD)+obj.Tracks(:,CGGTTS.STTIME)/86400,obj.Tracks(:,CGGTTS.DSG)*0.1,'.');
			title(titleText);
			xlabel('t');
			ylabel('DSG (ns)');
		end
        
		function PlotVisibility(obj,titleText)
			plot(obj.Tracks(:,CGGTTS.AZTH)*0.1,obj.Tracks(:,CGGTTS.ELV)*0.1,'.');
			%polarplot(obj.Tracks(:,CGGTTS.AZTH)*0.1*pi/180.0,cos(obj.Tracks(:,CGGTTS.ELV)*0.1*pi/180.0),'o');
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
        
		function [refgps]=AverageREFGPS(obj,useiono)
			% Calculate the averaged value of the measurand at each 
			% obervation time. Useful for REFSV etc
								
			if (obj.Sorted == 0) % only do it once
				obj.SortSVN(); 
			end;
			
			iono=1;
			if (useiono==1)
				iono=0;
			end;
			
			n = size(obj.Tracks(),1);
			i=1;
			av=0;
			cnt=0;
			sampcnt=0;
			lastmjd=obj.Tracks(i,CGGTTS.MJD);
			lastst=obj.Tracks(i,CGGTTS.STTIME);
		
			while (i<=n)
				if (obj.Tracks(i,CGGTTS.MJD) == lastmjd && obj.Tracks(i,CGGTTS.STTIME) == lastst)
					av = av + obj.Tracks(i,CGGTTS.REFGPS) + iono*obj.Tracks(i,CGGTTS.MDIO);
					sampcnt=sampcnt+1;    
				else
					av =av/sampcnt;
					cnt=cnt+1;
					refgps(cnt,:) = [ lastmjd+lastst/86400.0 av ];
					av=obj.Tracks(i,CGGTTS.REFGPS) + iono*obj.Tracks(i,CGGTTS.MDIO);
					sampcnt=1;
						
				end
				lastmjd=obj.Tracks(i,CGGTTS.MJD);
				lastst=obj.Tracks(i,CGGTTS.STTIME);
				i=i+1;
			end
			av =av/sampcnt; % add the last one
			cnt=cnt+1;
			refgps(cnt,:) = [lastmjd+lastst/86400.0 av];
		end
        
	end % of methods
    
	methods (Access='private')
	
		function SortSVN(obj)
			% Sorts tracks by SVN within each time block
			% as defined by MJD and STTIME
			% This is to make track matching easier
			n = size(obj.Tracks(),1);
			lastmjd=obj.Tracks(1,CGGTTS.MJD);
			lastst =obj.Tracks(1,CGGTTS.STTIME);
			stStart=1;
			for i=2:n
				if (obj.Tracks(i,CGGTTS.MJD) == lastmjd && ...
					obj.Tracks(i,CGGTTS.STTIME)==lastst)
					% sort
					j=i;
					while (j > stStart)
						if (obj.Tracks(j,CGGTTS.PRN) < obj.Tracks(j-1,CGGTTS.PRN))
								tmp = obj.Tracks(j-1,:);
								obj.Tracks(j-1,:)= obj.Tracks(j,:);
								obj.Tracks(j,:)=tmp;
						else
								break;
						end
						j=j-1;
					end
				else
					lastmjd=obj.Tracks(i,CGGTTS.MJD);
					lastst=obj.Tracks(i,CGGTTS.STTIME);
					stStart=i;
					% nothing more to do
				end
			end
			obj.Sorted=1;
		end
		
	end % methods

end % class



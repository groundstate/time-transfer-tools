classdef RINEXobs < matlab.mixin.Copyable
% RINEXObs - a class for reading RINEX observation files
% Usage:
%   obs=RINEXObs(filename)
%
% Currently supports RINEX V2 only (written to v2.11 specification)
%Author: MJW
% 
%RINEXobs Properties:
%   ver - RINEX version
%   gps - 3-D matrix of GPS measurements (time,sv no.,measurement)
%   t - vector of measurement times 
%   obsTypes - vector of observation types - the index is the data column
%   nobsTypes - number of observation types, for convenience
%
%RINEXobs Methods:
%   hasObservation - whether an observation is present
%   obsColumn - data column containing an observation type
%   match - match measurements
%   avprdiff - averaged pseudorange differences 
% Tested on Septentrio v2.11 RINEX
% 
%License
%The MIT License (MIT)
% 
%Copyright (c) 2017 Michael J. Wouters
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
%

    properties
        ver; % RINEX version
        gps; % 3-D matrix of GPS measurements (time,sv no.,measurement)
        t;   % measurement times 
        obsTypes; % vector of observation types - the index is the data column
        nobsTypes; % number of observation types, for convenience
    end
    
    properties (Constant)
        % observaton types
        C1=1;
        L1=2;
        L2=3;
        P1=4;
        P2=5;
        C2=6;
        C5=7;
        L5=8;
        S1=9;
        S2=10;
        % constellations
        GPS=1;
    end
    
    properties (Constant,Access=private)
        NSV_GPS=32;
    end
    
    methods (Access='public')
        function obj=RINEXobs(fname)
            fobs=fopen(fname);
            
            % Parse the header
            while (~feof(fobs))
                l = fgetl(fobs);
                if (contains(l,'RINEX VERSION'))
                    obj.ver = strtrim(l(1:9));
                    if (str2double(ver) >= 3)
                        error('RINEXobs:RINExobs',['Version ',ver,' is not supported yet (2.xx only)']);
                    end
                    continue;
                end
                % FIXME should check the time of first and last obs
                % and the interval
                if (contains(l,'TYPES OF OBSERV'))
                    obj.nobsTypes = str2num(l(1:6));
                    obj.obsTypes = zeros(1,obj.nobsTypes);
                    % Use zero because this is the convention in RINEX for
                    % missing data
                    % The data structure wastes memory but is easier to
                    % work with for time-transfer, where we want to match
                    % observations
                    gps = zeros(2900,RINEXobs.NSV_GPS,obj.nobsTypes); % extra for duplicates
                    obsl = sprintf('%-80s',l); % pad it
                    % Append any continuation lines UNTESTED
                    nlines = ceil((obj.nobsTypes-9)/9);
                    for line=2:nlines % first one done
                        nl =  sprintf('%-80s',getl(fobs));
                        obsl=strcat(obsl,nl);
                    end
                    for i=1:obj.nobsTypes
                        currline = floor(i/10);
                        tobs = obsl(currline*80+i*6 + 5: currline*80+(i+1)*6);
                        %fprintf('%s\n',tobs);
                        if (strcmp(tobs,'C1'))
                            obj.obsTypes(i)=RINEXobs.C1;
                        elseif (strcmp(tobs,'L1'))
                            obj.obsTypes(i)=RINEXobs.L1;
                        elseif (strcmp(tobs,'L2'))
                            obj.obsTypes(i)=RINEXobs.L2;
                        elseif (strcmp(tobs,'P1'))
                            obj.obsTypes(i)=RINEXobs.P1;
                        elseif (strcmp(tobs,'P2'))
                            obj.obsTypes(i)=RINEXobs.P2;
                        elseif (strcmp(tobs,'C2'))
                            obj.obsTypes(i)=RINEXobs.C2;
                        elseif (strcmp(tobs,'C5'))
                            obj.obsTypes(i)=RINEXobs.C5;
                        elseif (strcmp(tobs,'L5'))
                            obj.obsTypes(i)=RINEXobs.L5;
                        elseif (strcmp(tobs,'S1'))
                            obj.obsTypes(i)=RINEXobs.S1;
                        elseif (strcmp(tobs,'S2'))
                            obj.obsTypes(i)=RINEXobs.S2;
                        else
                            fprintf('Ignored %s\n',tobs);
                        end
                    end
                    continue;
                end
                if (contains(l,'END OF HEADER'))
                    break;
                end
            end
            
            % Now read the data file
            t = NaN(2900,1); % current observation time in seconds
            cnt = 0;
            while (~feof(fobs))
                l = fgetl(fobs);
                
                % fprintf('%d %s',t,l);
                % year 2:3,month 5:6,day 8:9,hr 11:12, min 14:15,sec 16:26
                hr = str2double(l(11:12));
                min = str2double(l(14:15));
                sec = str2double(l(16:26));
                cnt = cnt+1;
                t(cnt)= hr*3600 + min*60+sec; 
                nsats =str2num(l(30:32));
                % fprintf('%d %d %d\n',hr,min,sec);
                % Build a string of all SVIDs for parsing
                if (nsats <=12)
                    sats = l(33:(33+nsats*3-1));
                else
                    sats = l(33:(33+12*3-1));
                    %fprintf('Multiline\n');
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
                    if (svid(1)=='G')
                        prn = str2num(svid(2:3));
                        % If more than 5 observations then there are
                        % multiple lines to read
                        obstr = '';
                        nlines = ceil((obj.nobsTypes-5)/5)+1;
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
                        for o=1:obj.nobsTypes
                            % fprintf('%d %s %d %s\n',cnt,svid,o,obstr(1+(o-1)*16:1+(o-1)*16+13));
                            pr = str2double(obstr(1+(o-1)*16:1+(o-1)*16+13));
                            % Missing data can be flagged as zero or
                            % 'blank' so the conversion can fail
                            if (~isnan(pr))
                                gps(cnt,prn,o) = pr;
                            end
                        end
                        % gps(cnt,prn,:)
                        % fprintf('\n');
                    else % skip it
                        nlines = ceil((obj.nobsTypes-5)/5)+1;
                        for line=1:nlines
                            fgetl(fobs);
                        end    
                    end
                    
                end
                %fprintf('%d %s\n',nsats,sats);
            end
            obj.gps = gps;
            obj.t = t;
            % Now clean up the arrays by deleting missing measurement
            % epochs
            bad = isnan(obj.t);
            obj.gps(bad,:,:)=[];
            obj.t(bad)=[];
            fclose(fobs);
        end % of RINEXObs
        
        function [ok] = hasObservation(obj,obsType)
            ok = false;
            for i=1:obj.nobsTypes
                if (obj.obsTypes(i) == obsType)
                    ok=true;
                    break;
                end
            end
        end
        
        function [col]     = obsColumn(obj,obsType)
        % Returns the column in the GNSS observation matrix
        % containing the specified observation.
        % Zero is returned if it's missing
            col =0;
            for i=1:obj.nobsTypes
                if (obj.obsTypes(i) == obsType)
                    col = i;
                    break;
                end
            end
        end
        
        function [matches] = match(obj,rnxobs,constellation,obsType)
        % Compares with another set of GNSS observations, and returns
        % time-matched observations for the specified constellation and 
        % observation type. 
        % The format of the matrix is [][svn][time,obs1,obs2]
   
        
            if (nargin > 4)
                error('RINEXobs:match:TooManyInputs', 'requires at most 2 optional arguments');
            end

            defaults = {RINEXobs.GPS,RINEXobs.C1};

            switch nargin
                case 2
                    [constellation,obsType] = defaults{:};
                case 3
                    obsType=defaults{2};
            end
        
        % Some inanity checks
        
            if (~obj.hasObservation(obsType))
                error('RINEXobs:matchObservations','observation missing');
            end
            
            if (~rnxobs.hasObservation(obsType))
                error('RINEXobs:matchObservations','observation missing');
            end
            
            obscol1 = obj.obsColumn(obsType);
            obscol2 = rnxobs.obsColumn(obsType);
            
            if (constellation == RINEXobs.GPS)
                o1=obj.gps;
                o2=rnxobs.gps;
                nsv=RINEXobs.NSV_GPS;
            else
                error('RINEXobs:matchObservations','invalid constellation');
            end
            
       % Allocate storage
            s1 = length(obj.t)-sum(isnan(obj.t));
            s2 = length(rnxobs.t)-sum(isnan(rnxobs.t));
            %fprintf('%d %d\n',s1,s2);
            s = max(s1,s2);
            matches = NaN(s,nsv,3);
            
            tj = 1;
            ti = 1;
            nmatches=0;
            while ((ti <= length(obj.t)) && (tj <= length(rnxobs.t)))
                if (rnxobs.t(tj) == obj.t(ti))
                    nmatches=nmatches+1;
                    for sv=1:nsv
                        matches(nmatches,sv,1)=obj.t(ti);
                        m1 = o1(ti,sv,obscol1);
                        m2 = o2(tj,sv,obscol2);
                        matches(nmatches,sv,2)=m1;
                        matches(nmatches,sv,3)=m2;
                    end
                    tj = tj + 1;
                    ti = ti + 1;
                    continue;
                end
                if (rnxobs.t(tj) < obj.t(ti))
                    tj = tj + 1;
                    continue;
                end
                if (rnxobs.t(tj) > obj.t(ti))
                    ti = ti + 1;
                    continue;
                end
                
            end
        end % of match()
        
        function [matches] = avprdiff(obj,rnxobs,constellation,obsType)
            % Returns a vector of averaged pseudorange differences at each
            % measurement time for the specified constellation and
            % observation type (where there are matches)
            if (nargin > 4)
                error('RINEXobs:match:TooManyInputs', 'requires at most 2 optional arguments');
            end

            defaults = {RINEXobs.GPS,RINEXobs.C1};

            switch nargin
                case 2
                    [constellation,obsType] = defaults{:};
                case 3
                    obsType=defaults{2};
            end
        
        % Some inanity checks
        
            if (~obj.hasObservation(obsType))
                error('RINEXobs:matchObservations','observation missing');
            end
            
            if (~rnxobs.hasObservation(obsType))
                error('RINEXobs:matchObservations','observation missing');
            end
            
            if (constellation == RINEXobs.GPS)
                nsv=32;
            else
                error('RINEXobs:matchObservations','invalid constellation');
            end
            
            all = obj.match(rnxobs,constellation,obsType);
        
            matches=NaN(length(all),2);
            
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
            
        end % 
    
    end
    
   
end


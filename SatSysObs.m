classdef SatSysObs < matlab.mixin.Copyable
% SatSysObs - a class to hold RINEX observations for a satellite system
% Usage:
%   obs=SatSysObj(name)
%
% Known bugs: 
%
% SATSYSOBJ Properties:
%		satellite system name:
%   obsTypes - cell array of observation types - the index is the data column
%   nobsTypes - number of observation types, for convenience
%
% SATSYSOBJ Methods:
%
% 
% Examples:   
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
		name;
		obs; % 3-D matrix of measurements (time,sv no.,measurement)
		obsTypes; % cell array of observation types - the index is the data column
		nobsTypes; % not strictly the number of observation types
		empty;
	end
	
	methods (Access='public')
	
		function obj=SatSysObs(sysName)
			obj.name=sysName;
			obj.empty=true;
			obsTypes={};
			nobsTypes=0;
		end % SatSysObs()
		
		function allocate(obj,nobs,nsv)
			obj.obs=zeros(nobs,nsv,obj.nobsTypes);
		end
		
	end % methods 'public'
	
end % classdef
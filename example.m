%
% Simple examples
%

% RINEX 
% Load a few files. These receivers are on the same antenna so 
% average differences should be within +/- 1 ns or so of each other.
%

sep1=RINEX2O('data/SEP10130.17O','showProgress','yes')
sydn=RINEX2O('data/SYDN0130.17O','showProgress','yes')
sep3=RINEX2O('data/SEP30130.17O','showProgress','yes')

% Calculate the averaged pseudorange differences for C1 measurements
avpr = sep1.avPrDiff(sep3,RINEX2O.GPS,'C1');
figure(1)
plot(avpr(:,1),avpr(:,2)*1.0E9/3.0E8,'o');
xlabel('t (s)');
ylabel('C1 delta (ns)');
title('SEP1-SEP3: GPS');

avpr = sydn.avPrDiff(sep3,RINEX2O.GLONASS,'C1');
figure(2)
plot(avpr(:,1),avpr(:,2)*1.0E9/3.0E8,'o');
xlabel('t (s)');
ylabel('C1 delta (ns)');
title('SYDN-SEP3: GLONASS');



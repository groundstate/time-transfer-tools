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

% CGGTTS
% Load a few files, match them 
% 

% A version 2E file, single frequency
rx01=CGGTTS(57607,57607,'./data/','GMRX01','NamingConvention','BIPM');
% Remove tracks below 25 degrees elevation
rx01.Filter(rx01.ELV,250,900); % note units!

% A version 1 file, dual frequency
% (Observations are C/A, not P3)
rx02=CGGTTS(57607,57607,'./data/','GMRX02','NamingConvention','BIPM');
rx02.Filter(rx02.ELV,250,900);

% Match the tracks
[m1,m2]=rx01.match(rx02);

% These two receivers share a common clock and are on a relatively short baseline
% Calculate the REFSV difference  for the matched clocks 
% Note that we use each class instance to look up indices for coulmns in the CGGTTS file 
% - this is because there are differences between single and dual frequency files 
refsv = (m1.Tracks(:,m1.REFSV)+m1.Tracks(:,m1.MDIO)+m1.Tracks(:,m1.MDTR)-m2.Tracks(:,m2.REFSV)-m2.Tracks(:,m2.MDIO)-m2.Tracks(:,m2.MDTR))/10.0; % in ns

figure(3);
plot(m1.Tracks(:,m1.STTIME),refsv,'+');
xlabel('t (s)');
ylabel('REFSV delta (ns)');
title('RX01-RX02 time transfer');

% Linear fit to data
px = polyfit(m1.Tracks(:,m1.STTIME),refsv,1);

% Compare the raw time offset, estimated three ways
fprintf('Mean offset = %g\n',mean(refsv));
fprintf('Median offset = %g\n',median(refsv));
fprintf('Linear fit, evaluated at the centre = %g\n',px(1)*43200+px(2));
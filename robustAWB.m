function robustAWB(filename,outFile,option,catType,T,maxIter,plots)
%robustAWB(filename,outFile,option,catType,T,maxIter,plot)
% Performs robust auto white-balancing by estimating gray pixels based on
% their deviation in YUV space then applying an iterative correction via
% CAT or directly adjusting the R and B channels.
% Set option = 'RB gain' or 'cat' for the correction method.
% Set T higher for a larger threshold of deviation to consider off-gray.
% Set plot = 0 or 1 to turn diagnostic plots on or off.

%tutorialinit
maxIter=100;
T=10;
option='RB gain' ;
catType='sharp';
%% import image
im_orig = imread('pic1.jpeg');
img1= imread('pic1.jpeg');
im_orig = double(im_orig);
% figure
% imshow(im_orig)
% title('Original Image')

%% various constants
xyz_D65 = [95.04; 100; 108.88]; %http://en.wikipedia.org/wiki/D65, normalized Y = 100

sRGBtoXYZ =   [0.4124564  0.3575761  0.1804375; ...
               0.2126729  0.7151522  0.0721750; ...
               0.0193339  0.1191920  0.9503041];

%% robust auto white balance - YUV grays
% option = 'RB gain'; % adjustments are done as a gain to only R or B channelas descripted in Huo
% option = 'cat';
% catType = 'CAT02';

% maxIter = 1000;

% T = 0.3; %this should be tweakable slider
% T = 0.1;
% gain adjustment parameters, can probably be optimized via more control system analysis
u = .01; %gain step size
a = .8; %double step threshold
b = .001; %convergence threshold

% rgb to yuv
xfm =   [0.299 0.587 0.114; ...
        -0.299 -0.587 0.886; ...
        0.701 -0.587 -0.114];
    
inv_xfm = inv(xfm);
    
%imRGB_orig = cbreshape(im_orig)*255;

s = size(im_orig);
m = s(1); n = s(2);
size(im_orig)
imRGB_orig = reshape(permute(im_orig,[3 1 2]),[3 m*n 1]);

imRGB = imRGB_orig;
gain = [1 1 1];

U_avg = [];
V_avg = [];
totGray = [];
for iter = 1:maxIter
    im = xfm*imRGB; %convert to YUV
    % find gray chromaticity
    % (|U|+|V|)/Y
    F = ( abs(im(2,:)) + abs(im(3,:)) )./im(1,:);
    
%     figure
%     imshow(cbunshape(imRGB/255.*repmat(F<T,3,1),size(im_orig)))
%     % imshow(cbunshape(inv_xfm)*im+[F>T;zeros(2,length(F))],size(im_orig))) %rubylith overlays
%     title('Gray Pixels Found by Robust AWB'),xlabel('Pixels in their original color are considered gray')
    
    totGray = [totGray sum(F<T)];
    if totGray(end) == 0
        disp('No valid gray pixels found.')
        break
    end
    grays = im(:,F<T);
    U_bar = mean(grays(2,:));
    V_bar = mean(grays(3,:));
    
    U_avg = [U_avg U_bar];
    V_avg = [V_avg V_bar];
    
    if strcmpi(option,'cat')
        if max(abs([U_bar V_bar])) < b
            disp(['Converged. U_bar and V_bar < ' num2str(b) ' in magnitude.'])
            break
        elseif iter >= 2 && norm([U_avg(end)-U_avg(end-1) V_avg(end)-V_avg(end-1)]) < 10^-6
            disp(['U_bar and V_bar are no longer improving.'])
            break
        end
        rgbEst = inv_xfm*[100;U_bar;V_bar]; %convert the average gray from YUV to RGB
        %
        xyz= sRGBtoXYZ*rgbEst;
        a1 = xyz(1);
        a2 = xyz(2);
        a3 = sum(xyz);
        xyEst = [a1/a3; a2/a3];
        
        %
        %xyEst = XYZ2xy(sRGBtoXYZ*rgbEst); %calculate xy chromaticity
        a1 = xyEst(1); b1 = xyEst(2);c1=100;
        xyzEst = [c1/b1*a1; c1; c1/b1*(1-a1-b1)];
        %xyzEst = xy2XYZ(xyEst,100); %normalize Y to 100 so D65 luminance comparable
        imRGB = cbCAT(xyzEst,xyz_D65,catType)*imRGB;
    else
        if abs(U_bar) > abs(V_bar) % U > V; blue needs adjustment
            err = U_bar;
            ch = 3; %blue channel
        else
            err = V_bar;
            ch = 1; %red channel
        end
        if abs(err) >= a
            delta = 2*sign(err)*u; %accelerate gain adjustment if far off
        elseif abs(err) < b %converged
            delta = 0;
            disp(['Converged. U_bar and V_bar < ' num2str(b) ' in magnitude.'])
            break
        else
            delta = err*u;
        end
%         [err,delta]
        gain(ch) = gain(ch)-delta; %negative fdbk loop
        imRGB = diag(gain)*imRGB_orig;
    end
end
sz=size(im_orig);
width = sz(1); height = sz(2);
out = reshape(imRGB,[3,width,height]);
out = permute(out,[2 3 1]);

%imshow(im_orig);
subplot(1,2,1), imshow(img1);
subplot(1,2,2), imshow(out/255);
title('Robust AWB Corrected');
% figure
% imshow(cbunshape(imRGB,size(im_orig))/255)
% title('Robust AWB Corrected')
end
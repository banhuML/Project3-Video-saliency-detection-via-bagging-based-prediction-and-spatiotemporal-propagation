function [L,a,b] =rgb2lab_dong(R,G,B)
%% Modified by Dong Zhang, Center for Research in Computer Vision, UCF 1/10/2014
% function [L, a, b] = RGB2Lab(R, G, B)
% RGB2Lab takes matrices corresponding to Red, Green, and Blue, and 
% transforms them into CIELab.  This transform is based on ITU-R 
% Recommendation  BT.709 using the D65 white point reference.
% The error in transforming RGB -> Lab -> RGB is approximately
% 10^-5.  RGB values can be either between 0 and 1 or between 0 and 255.  
% By Mark Ruzon from C code by Yossi Rubner, 23 September 1997.
% Updated for MATLAB 5 28 January 1998.
output_flag=0;
if (nargin == 1)
    if size(R,3)==3
        output_flag=1;
        B = double(R(:,:,3));
        G = double(R(:,:,2));
        R = double(R(:,:,1));
    elseif (size(R,3)==1)&&(size(R,1)==3)&&(size(R,2)~=3)
        output_flag=2;
        B=double(R(3,:));
        G=double(R(2,:));
        R=double(R(1,:));
    elseif (size(R,3)==1)&&(size(R,1)~=3)&&(size(R,2)==3)
        output_flag=3;
        B=double(R(:,3));
        G=double(R(:,2));
        R=double(R(:,1));
    end
end

if ((max(max(R)) > 1.0) | (max(max(G)) > 1.0) | (max(max(B)) > 1.0))
  R = R/255;
  G = G/255;
  B = B/255;
end

[M, N] = size(R);
s = M*N;

% Set a threshold
T = 0.008856;

RGB = [reshape(R,1,s); reshape(G,1,s); reshape(B,1,s)];

% RGB to XYZ
MAT = [0.412453 0.357580 0.180423;
       0.212671 0.715160 0.072169;
       0.019334 0.119193 0.950227];
XYZ = MAT * RGB;

X = XYZ(1,:) / 0.950456;
Y = XYZ(2,:);
Z = XYZ(3,:) / 1.088754;

XT = X > T;
YT = Y > T;
ZT = Z > T;

fX = XT .* X.^(1/3) + (~XT) .* (7.787 .* X + 16/116);

% Compute L
Y3 = Y.^(1/3); 
fY = YT .* Y3 + (~YT) .* (7.787 .* Y + 16/116);
L  = YT .* (116 * Y3 - 16.0) + (~YT) .* (903.3 * Y);

fZ = ZT .* Z.^(1/3) + (~ZT) .* (7.787 .* Z + 16/116);

% Compute a and b
a = 500 * (fX - fY);
b = 200 * (fY - fZ);

L = reshape(L, M, N);
a = reshape(a, M, N);
b = reshape(b, M, N);

if ((nargout == 1) | (nargout == 0))
    if output_flag==1
        L = cat(3,L,a,b);
    elseif output_flag==2
        L=[L;a;b];
    elseif output_flag==3
        L=[L,a,b];
    else
        disp('Error');
    end
end
function [A, B] = generateAB(length, optPDF, X, M, Sig)
%% Data generation for AX = XB problem


%% Initialization
A = zeros(4, 4, length);
B = zeros(4, 4, length);

if optPDF == 1
    
    for i = 1:length
        B(:,:,i) = expm(se3_vec(mvg(M, Sig, 1)));
        A(:,:,i) = X*B(:,:,i)*X^-1; 
    end
    
elseif optPDF == 2
    
    % The followingis manually set 
    B_true = trotx(0)*troty(0);
    B_true(1:3,4) = 0.01*rand([3,1]);
    
    for i = 1:size(B,3)
        B(:,:,i) = B_true;
    end
    
    % Assume Sig is a diagonal matrix with the same diagonal elements
    B = sensorNoise(B, M, Sig(1), 1);
    
    for i = 1:size(A,3)
        A(:,:,i) = X*B(:,:,i)/X;
    end
    
elseif optPDF == 3
    
    % The followingis manually set 
    B_true = trotx(rand*30)*troty(rand*40);
    B_true(1:3,4) = 0.1*rand([3,1]);
    
    for i = 1:size(B,3)
        B(:,:,i) = B_true*expm(se3_vec(mvg(M, Sig, 1)));
    end
    
    for i = 1:size(A,3)
        A(:,:,i) = X*B(:,:,i)/X;
    end

elseif optPDF == 4
    
    % The followingis manually set 
    B_true = trotx(30)*troty(40);
    B_true(1:3,4) = 0.1*rand([3,1]);
    
    for i = 1:size(B,3)
        B(:,:,i) = B_true*expm(se3_vec(mvg(M, Sig, 1)));
    end
    
    for i = 1:size(A,3)
        A(:,:,i) = X*B(:,:,i)/X;
    end
end

end
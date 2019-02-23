clear; clc;
close all;

% experimental parameters
nl= 5; % level of noise
npts= [100:100:1000]; % number of points
num= 1; % total number of trials

% compared methods
A= zeros(size(npts));
B= zeros(num,1);

addpath(genpath('../3rdparty/PnP_Toolbox-master/PnP_Toolbox-master/code'));

name= {'EPnP+GN', 'RPnP','EPPnP','REPPnP','epnp_re_ransac'};
f= {@EPnP_GN, @RPnP, @EPPnP,  @REPPnP, @epnp_re_ransac2};
marker= { 'x', 's',      'd',      '^', '>'};%,            '>',   '<',      'v',      '*',    '+',     '^',    'x'};
color= {'r',   'g',      [1,0.5,0],'m', 'c'};%,            'c',   'b',      'y',      [1,0.5,1],[0,0.5,1],   'r',    'k'};
markerfacecolor=  {'r','g',[1,0.5,0],'m',  'c'};%,          'c',   'b',      'y',      'n',      'n',   'r',    'k'};

method_list= struct('name', name, 'f', f, 'mean_r', A, 'mean_t', A,...
    'med_r', A, 'med_t', A, 'std_r', A, 'std_t', A, 'r', B, 't', B,...
    'marker', marker, 'color', color, 'markerfacecolor', markerfacecolor);

% experiments
for i= 1:length(npts)
    
    npt= npts(i);
    fprintf('npt = %d (sg = %d px): ', npt, nl);   
    
     for k= 1:length(method_list)
        method_list(k).c = zeros(1,num);
        method_list(k).e = zeros(1,num);
        method_list(k).r = zeros(1,num);
        method_list(k).t = zeros(1,num);
    end
    
    index_fail = cell(1,length(name));
    
    for j= 1:num
        
        % camera's parameters
        f= 1000;
        
        % generate 3d coordinates in camera space
        Xc= [xrand(1,npt,[-2 2]); xrand(1,npt,[-2 2]); xrand(1,npt,[4 8])];
        t= mean(Xc,2);
        R= rodrigues(randn(3,1));
        XXw= inv(R)*(Xc-repmat(t,1,npt));
        
        % projection
        xx= [Xc(1,:)./Xc(3,:); Xc(2,:)./Xc(3,:)]*f;
        randomvals = randn(2,npt);
        xxn= xx+randomvals*nl;
		
        % pose estimation
        for k= 1:length(method_list)
            try
               if strcmp(method_list(k).name, 'R1PPnP')
                   tic;
                   [R1,t1]= method_list(k).f(XXw,xxn/f);
                   tcost = toc;
               else
                   tic;
                   [R1,t1]= method_list(k).f(XXw,xxn/f);
                   tcost = toc;
               end
            catch
                disp(['The solver - ',method_list(k).name,' - encounters internal errors!!!']);
                %index_fail = [index_fail, j];
                index_fail{k} = [index_fail{k}, j];
                break;
            end
            
            %no solution
            if size(t1,2) < 1
                disp(['The solver - ',method_list(k).name,' - returns no solution!!!']);
                %index_fail = [index_fail, j];
                index_fail{k} = [index_fail{k}, j];
                break;
            elseif (sum(sum(sum(imag(R1).^2))>0) == size(R1,3) || sum(sum(imag(t1(:,:,1)).^2)>0) == size(t1,2))
                index_fail{k} = [index_fail{k}, j];
                continue;
            end
            %choose the solution with smallest error 
            error = inf;
            for jjj = 1:size(R1,3)
                tempy = cal_pose_err([R1(:,:,jjj) t1(:,jjj)],[R t]);
                if sum(tempy) < error
                    cost  = tcost;
                    ercorr= mean(sqrt(sum((R1(:,:,jjj) * XXw +  t1(:,jjj) * ones(1,npt) - Xc).^2)));
                    y     = tempy;
                    error = sum(tempy);
                end
            end
            
            method_list(k).c(j)= cost * 1000;
            method_list(k).e(j)= ercorr;
            method_list(k).r(j)= y(1);
            method_list(k).t(j)= y(2);
        end

        showpercent(j,num);
    end
    fprintf('\n');
    
    % save result
    for k= 1:length(method_list)
       %results without deleting solutions
            tmethod_list = method_list(k);
            method_list(k).c(index_fail{k}) = [];
            method_list(k).e(index_fail{k}) = [];
            method_list(k).r(index_fail{k}) = [];
            method_list(k).t(index_fail{k}) = [];

            % computational cost should be computed in a separated procedure as
            % in main_time.m
            
            method_list(k).pfail(i) = 100 * numel(index_fail{k})/num;
            
            method_list(k).mean_c(i)= mean(method_list(k).c);
            method_list(k).mean_e(i)= mean(method_list(k).e);
            method_list(k).med_c(i)= median(method_list(k).c);
            method_list(k).med_e(i)= median(method_list(k).e);
            method_list(k).std_c(i)= std(method_list(k).c);
            method_list(k).std_e(i)= std(method_list(k).e);

            method_list(k).mean_r(i)= mean(method_list(k).r);
            method_list(k).mean_t(i)= mean(method_list(k).t);
            method_list(k).med_r(i)= median(method_list(k).r);
            method_list(k).med_t(i)= median(method_list(k).t);
            method_list(k).std_r(i)= std(method_list(k).r);
            method_list(k).std_t(i)= std(method_list(k).t);
           
            %results deleting solutions where not all the methods finds one
            tmethod_list.c(unique([index_fail{:}])) = [];
            tmethod_list.e(unique([index_fail{:}])) = [];
            tmethod_list.r(unique([index_fail{:}])) = [];
            tmethod_list.t(unique([index_fail{:}])) = [];
            
            method_list(k).deleted_mean_c(i)= mean(tmethod_list.c);
            method_list(k).deleted_mean_e(i)= mean(tmethod_list.e);
            method_list(k).deleted_med_c(i)= median(tmethod_list.c);
            method_list(k).deleted_med_e(i)= median(tmethod_list.e);
            method_list(k).deleted_std_c(i)= std(tmethod_list.c);
            method_list(k).deleted_std_e(i)= std(tmethod_list.e);

            method_list(k).deleted_mean_r(i)= mean(tmethod_list.r);
            method_list(k).deleted_mean_t(i)= mean(tmethod_list.t);
            method_list(k).deleted_med_r(i)= median(tmethod_list.r);
            method_list(k).deleted_med_t(i)= median(tmethod_list.t);
            method_list(k).deleted_std_r(i)= std(tmethod_list.r);
            method_list(k).deleted_std_t(i)= std(tmethod_list.t);
    end
end

% save ../results/ordinary3DresultsNpts method_list npts;

close all;

i= 0; w= 300; h= 300;

yrange= [0 1.2*max([method_list(:).deleted_med_r])];
yrange= [0 3];

figure('color','w','position',[w*i,100,w,h]);%i=i+1;
xdrawgraph(npts,yrange,method_list,'deleted_mean_r','Mean Rotation Error',...
    'Number of Points','Rotation Error (degrees)');

figure('color','w','position',[w*i,100+h,w,h]);i=i+1;
xdrawgraph(npts,yrange,method_list,'deleted_med_r','Median Rotation Error',...
    'Number of Points','Rotation Error (degrees)');

yrange= [0 1.2*max([method_list(:).deleted_med_t])];
yrange= [0 1];

figure('color','w','position',[w*i,100,w,h]);%i=i+1;
xdrawgraph(npts,yrange,method_list,'deleted_mean_t','Mean Translation Error',...
    'Number of Points','Translation Error (%)');

figure('color','w','position',[w*i,100+h,w,h]);i=i+1;
xdrawgraph(npts,yrange,method_list,'deleted_med_t','Median Translation Error',...
    'Number of Points','Translation Error (%)');

yrange= [0 1.2*max([method_list(:).deleted_med_e])];

figure('color','w','position',[w*i,100,w,h]);%i=i+1;
xdrawgraph(npts,yrange,method_list,'deleted_mean_e','Mean L2 Error',...
    'Number of Points','L2 error');

figure('color','w','position',[w*i,100+h,w,h]);%i=i+1;
xdrawgraph(npts,yrange,method_list,'deleted_med_e','Median L2 Error',...
    'Number of Points','L2 error');

yrange= [0 min(max(1,2*max([method_list(:).pfail])),100)];
figure('color','w','position',[w*i,100+2*h,w,h]);%i=i+1;
xdrawgraph(npts*100,yrange,method_list,'pfail','No solution x method',...
    'Number of Points','% method fails');
i=i+1;

yrange= [0 1.2*max([method_list(:).deleted_med_c])];
yrange= [0 150];

figure('color','w','position',[w*i,100,w,h]);%i=i+1;
xdrawgraph(npts,yrange,method_list,'deleted_mean_c','Mean Cost',...
    'Number of Points','Cost (ms)');

figure('color','w','position',[w*i,100+h,w,h]);i=i+1;
xdrawgraph(npts,yrange,method_list,'deleted_med_c','Median Cost',...
    'Number of Points','Cost (ms)');
% saveas(9, '../results/figure10(a).png');

using LazyGrids: ndgrid, ndgrid_array
using LazyGrids: btime, @timeo # not exported; just for timing tests here
using BenchmarkTools: @benchmark
using InteractiveUtils: versioninfo
using MIRTjim: jim, prompt
using DelimitedFiles
using MAT
   # function output = ir_radon_zwart_powell(theta, yr)
   #
   # Compute analytic 2D Radon transform of Zwart-Powell box spline.
   #
   # in
   # theta -	ray angle in radian
   # rr	-distance between the point and the ray (normalized by the pixel size)
   # output: radon transform of the Zwart-Powell box spline element
   #
   # This is the modified version of the code written by [1]
   # to avoid symbolic math operation.
   # Code written by Seongjin Yoon, Univ. of Michigan, Jan 2015
   #
   # Reference
   # [1] A. Entezari, M. Nilchian, and M. Unser, "A box spline calculus
   # for the discretization of computed tomography reconstruction problems,"
   # IEEE Trans. Med. Imaging, vol. 31, no. 8, pp. 1532–1541, 2012.
   #
   # 2015-08-10 Jeff Fessler, added self test and parallelized
    # if nargin < 2, ir_usage, return, end

    function ir_radon_zwart_powell(theta, rr)
    dim = size(theta)
    theta = vec(theta); #converting the matrix theta into a vector with 18281 elements
    
    zeta = zeros(length(theta), 4); #Martrix zeta of dimensions: No. of rows = number of elements in Zeta, No. of coloumns = 4
    zeta[:,1] = cos.(theta);
    zeta[:,2] = sin.(theta);
    #zeta[:,2] = sin.(theta); #in the theta vector the values of above 3.146 gives at for example index 362
    # different values in matlab and julia.. this maybe a probably using the sin function
    zeta[:,3] .= zeta[:,1] .+ zeta[:,2];
    zeta[:,4] .= zeta[:,1] .- zeta[:,2]; 
    #cond = abs.(zeta) .>= eps(1.0)
    cond = abs.(zeta) .>= 1.1920929e-07  #eps('single') matlab different than eps(1.0)- julia
    N = sum(cond, dims = 2); #returns the sum of the row in the matrix
    N = vec(N);      
    output = BoxSp4(rr[:], zeta, cond, N) ./ factorial.(N.-1);
    output = reshape(output, dim);
    return output
    end 
    
    function BoxSp0(y, N)
    #output = heaviside(y) .* y.^(N-1);
    if any(size(y) != size(N)) 
      throw("Size don't match")
      end
      output = (y .>= 0) .* y.^(N .- 1)
      return output
    end

      #=function output = BoxSp0(y, N)
      %output = heaviside(y) .* y.^(N-1);
      if any(size(y) ~= size(N)), keyboard, end
      output = (y >= 0) .* y.^(N-1);
      end =#
    

    function BoxSp1(y, zeta, cond, N)
      good = cond[:,1]
      output = (BoxSp0(y .+ (0.5 .* zeta[:,1]), N) .- BoxSp0(y .- (0.5 .* zeta[:,1]), N)) ./ zeta[:,1]
      output[.~good] .= BoxSp0(y[.~good], N[.~good])
      return output
    end

    #= function output = BoxSp1(y, zeta, cond, N)
    good = cond(:,1);
    output = (BoxSp0(y+0.5*zeta(:,1), N) ...
	    - BoxSp0(y-0.5*zeta(:,1), N)) ./ zeta(:,1);
    output(~good) = BoxSp0(y(~good), N(~good));
    end =#
    
    function BoxSp2(y, zeta, cond, N)
      good = cond[:,2];
      output = (BoxSp1(y .+ (0.5.*zeta[:,2]), zeta, cond, N) .- BoxSp1(y .- (0.5 .* zeta[:,2]), zeta, cond, N)) ./ zeta[:,2];
      output[.~good] .= BoxSp1(y[.~good], zeta[.~good,:], cond[.~good,:], N[.~good]);
      return output 
    end

    #= function output = BoxSp2(y, zeta, cond, N)
      good = cond(:,2);
      output = (BoxSp1(y+0.5*zeta(:,2), zeta, cond, N) ...
        - BoxSp1(y-0.5*zeta(:,2), zeta, cond, N)) ./ zeta(:,2);
      output(~good) = BoxSp1(y(~good), zeta(~good,:), cond(~good,:), N(~good));
      end =#
    
    function BoxSp3(y, zeta, cond, N)
      good = cond[:,3];
      output = (BoxSp2(y .+ 0.5 .* zeta[:,3], zeta, cond, N) .- BoxSp2(y .- 0.5 .* zeta[:,3], zeta, cond, N)) ./ zeta[:,3];
      output[.~good] .= BoxSp2(y[.~good], zeta[.~good,:], cond[.~good,:], N[.~good]);
      return output;
    end

    #= function output = BoxSp3(y, zeta, cond, N)
    good = cond(:,3);
    output = (BoxSp2(y+0.5*zeta(:,3), zeta, cond, N) ...
	        - BoxSp2(y-0.5*zeta(:,3), zeta, cond, N)) ./ zeta(:,3);
    t = zeta(~good,:);
    output(~good) = BoxSp2(y(~good), t, cond(~good,:), N(~good));
    end =#
    
    function BoxSp4(y, zeta, cond, N)
      good = cond[:,4];
      output = (BoxSp3(y .+ 0.5 .* zeta[:,4], zeta, cond, N) .- BoxSp3(y .- 0.5 .* zeta[:,4], zeta, cond, N)) ./ zeta[:,4] 
      output[.~good] .= BoxSp3(y[.~good], zeta[.~good,:], cond[.~good,:], N[.~good]);
      return output; 
    end

    #= MatLab BoxSp4 code:
    function output = BoxSp4(y, zeta, cond, N)
      good = cond(:,4);
      output = (BoxSp3(y+0.5*zeta(:,4), zeta, cond, N) ...
        - BoxSp3(y-0.5*zeta(:,4), zeta, cond, N)) ./ zeta(:,4);
      output(~good) = BoxSp3(y(~good), zeta(~good,:), cond(~good,:), N(~good));
      end =#

  #Base.runtests()

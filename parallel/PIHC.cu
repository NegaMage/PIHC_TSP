#include"stdio.h"
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include"math.h"
#include <ctype.h>
#include <assert.h>

/* Euclidean distance calculation */
__host__ __device__ long distD(int i,int j,float *x,float*y)
{
	float dx=x[i]-x[j];
	float dy=y[i]-y[j]; 
	return(sqrtf( (dx*dx) + (dy*dy) ));
}
//all these strats are for the two opt move,
/*A kenel function that finds a minimal weighted neighbor using TPR mapping strategy*/
__global__ void tsp_tpr(float *pox,float *poy,long initcost,unsigned long long *dst_tid,long cit)
{
	//threads per row strategy
	long id,j;
	register long change,mincost=initcost,cost;
	long i=threadIdx.x+blockIdx.x*blockDim.x;
	if(i < cit)
	{	//
		
		for(j=i+1;j<cit;j++)
		{//pox and poy are arrays that store the positions (x y) of ith city
			change = 0; cost=initcost;
			change=distD(i,j,pox,poy)+distD((i+1)%cit,(j+1)%cit,pox,poy)-distD(i,(i+1)%cit,pox,poy)-distD(j,(j+1)%cit,pox,poy);
			cost+=change;	
			if(cost < mincost)
			{
				mincost = cost;
				id = i * (cit-1)+(j-1)-i*(i+1)/2;	
			}	 

		}
		if(mincost < initcost)
			 atomicMin(dst_tid, ((unsigned long long)mincost << 32) | id);

	}
	
}

/*A kenel function that finds a minimal weighted neighbor using TPRED mapping strategy*/
__global__ void tsp_tpred(float *pox,float *poy,long initcost,unsigned long long *dst_tid,long cit,long itr)
{
	long id,j,k;
	register long change,mincost=initcost,cost;
	long i=threadIdx.x+blockIdx.x*blockDim.x;
	if(i < cit)
	{
		//itr is how many iterations we can stand to do.
		for(k=0;k<itr;k++)
		{
			change = 0; cost=initcost;
			j=(i+1+k)%cit;
			change=distD(i,j,pox,poy)+distD((i+1)%cit,(j+1)%cit,pox,poy)-distD(i,(i+1)%cit,pox,poy)-distD(j,(j+1)%cit,pox,poy);
			cost+=change;	
			if(cost < mincost)
			{
				mincost = cost;
				if(i < j)
					id = i * (cit-1)+(j-1)-i*(i+1)/2;	
				else
					id = j * (cit-1)+(i-1)-j*(j+1)/2;	

			}	 

		}
		if(mincost < initcost)
			 atomicMin(dst_tid, ((unsigned long long)mincost << 32) | id);
	}
}

/*A kenel function that finds a minimal weighted neighbor using TPRC mapping strategy*/
__global__ void tsp_tprc(float *pox,float *poy,long initcost,unsigned long long *dst_tid,long cit)
{

	long id;
	long change,cost;
	long i=threadIdx.x+blockIdx.x*blockDim.x;
	long j=threadIdx.y+blockIdx.y*blockDim.y;
	//if city in bounds and the column you choose is more than the row, so there is no repeat issues
	if(i < cit && j < cit && i < j)
	{
		
			change = 0; cost = initcost;
			change=distD(i,j,pox,poy)+distD((i+1)%cit,(j+1)%cit,pox,poy)-distD(i,(i+1)%cit,pox,poy)-distD(j,(j+1)%cit,pox,poy);
			cost+=change;	
			if(change < 0)
			{
				id = i * (cit - 1) + (j - 1) - i * (i + 1) / 2;	
				atomicMin(dst_tid, ((unsigned long long)cost << 32) | id);
			}	 

	}
	
}

/*A kenel function that finds a minimal weighted neighbor using TPN mapping strategy*/
__global__ void tsp_tpn(float *pox,float *poy,long cost,unsigned long long *dst_tid,long cit,long sol)
{

	long i,j;
	register long change=0;
	int id=threadIdx.x+blockIdx.x*blockDim.x;
	if(id<sol)
	{
		
		i=cit-2-floorf(((int)__dsqrt_rn(8*(sol-id-1)+1)-1)/2);
		j=id-i*(cit-1)+(i*(i+1)/2)+1;
		change=distD(i,j,pox,poy)+distD((i+1)%cit,(j+1)%cit,pox,poy)-distD(i,(i+1)%cit,pox,poy)-distD(j,(j+1)%cit,pox,poy);
		cost+=change;	
		if(change < 0)
			 atomicMin(dst_tid, ((unsigned long long)cost << 32) | id);
		
	}
	
}

/* At each IHC steps, XY coordinates are arranged using next initial solution's order*/
void twoOpt(long x,long y,float *pox,float *poy)
{
	float *tmp_x,*tmp_y;
	int i,j;
	
	tmp_x=(float*)malloc(sizeof(float)*(y-x));	
	tmp_y=(float*)malloc(sizeof(float)*(y-x));	
	for(j=0,i=y;i>x;i--,j++)
	{
		tmp_x[j]=pox[i];
		tmp_y[j]=poy[i];
	}
	for(j=0,i=x+1;i<=y;i++,j++)
	{
		pox[i]=tmp_x[j];
		poy[i]=tmp_y[j];
	}
	free(tmp_x);
	free(tmp_y);

}


/*Arranges XY coordinates in initial solution's order*/
void setCoord(int *r,float *posx,float *posy,float *px,float *py,long cities)
{
	for(int i=0;i<cities;i++)
	{
		px[i]=posx[r[i]];
		py[i]=posy[r[i]];
	}
}
/* Initial solution construction using NN */
long nn_init(int *route,long cities,float *posx,float*posy)
{	//route stores the route taken, cities is the number of cities, posx and posy are the positions of the ith city
	route[0]=0;
	int k=1,i=0,j;
	float min;
	int minj,mini,count=1,flag=0;
	long dst=0;
	int *visited=(int*)calloc(cities,sizeof(int));
	visited[0]=1;
	while(count!=cities)
	{
		flag=0;
		for(j=1;j<cities;j++)
		{	//if j isn't visited yet
			if(i!=j && !visited[j])
			{
				min=distD(i,j,posx,posy);
				minj=j;
				break;	
			}
		}
		//for the minimum cost j
		for(j=minj+1;j<cities;j++)
		{//for every node from the min cost, if you haven't visited, then check and generate the pair
			
			 if( !visited[j])
			{
				if(min>distD(i,j,posx,posy))
				{
					min=distD(i,j,posx,posy);
					mini=j;
					flag=1;				
				}
			}
		}
		if(flag==0)
			i=minj;
		else
			i=mini;
		dst+=min;
		route[k++]=i;
		visited[i]=1;
		count++;
	}
	free(visited);
	dst+=distD(route[0],route[cities-1],posx,posy);
	return dst;
}
/* Initial solution construction using sequenced approach */
void seq_init(int*route,long N)
{
	int i;
	for(i=0;i<N;i++)
		route[i]=i;
}

/* Initial solution construction using random approach */
void random_init(int *route,long cities)
{
	int i=0,j;
	int *visited = (int*)calloc(cities,sizeof(int));
	
	while(i<cities)
	{
		//srand (clock() );
		j=rand() % cities;
		if(visited[j])
		{
			continue;
		}
		else
		{
			route[i]=j;
			visited[j]=1;
			i++;	
		}

	}
	free(visited);
}

struct nearest_insert
{
	int city;
	struct nearest_insert *next;
};
struct odd_degree
{
	int city;
	struct odd_degree *next;
};	
struct rev_visit
{
int i,j;
struct rev_visit *next;
};

/* Initial solution construction using nearest insertion approach */
void nearest_insertion(int *r, float *posx, float *posy, long cities)
{
	struct nearest_insert *node,*p1,*tmp,*current,*route,*first = NULL;
	int i,j,dist,min=0;
	int count,minI,minJ; 
	int min_diff,diff,min_i,min_j; 
	int *v;
	v = (int *)calloc(cities, sizeof(int));
	node = (struct nearest_insert *)malloc(sizeof(struct nearest_insert ));
	node->city = 0;
	node->next = NULL;
	first = node;
	current = node;
	count = 1;
	v[0]=1;
	while(count != cities)
	{//as long as there are new cities
		min = 0;
		for(route = first; route != NULL; route=route->next)
		{//traverse the whole route to find the shortest edge
			i = route->city;
			for(j = 0; j < cities; j++)
			{
				if(i !=j &&!v[j])
				{
					dist = distD(i,j,posx,posy);
					if(min==0)
					{
						min=dist;
						minI=i;
						minJ=j;
	
					}
					if(min>dist)
					{
						min=dist;
						minI=i;
						minJ=j;
					}
				}
			}
		}
		//setting that node on edge to explored
		v[minJ]=1;
		//when you're starting out
		if(count < 3)
		{
			if(first->city == minI)
			{
				if(first->next == NULL)
				{
					node = (struct nearest_insert *)malloc(sizeof(struct nearest_insert ));
					node->city = minJ;
					node->next = NULL;
					first->next = node;
					current = current->next;
				}
				else
				{
					tmp = first->next;
					node = (struct nearest_insert *)malloc(sizeof(struct nearest_insert ));
					node->city = minJ;
					node->next = tmp;
					first->next = node;
				}
			}
			else if(current->city == minI)
			{
					node = (struct nearest_insert *)malloc(sizeof(struct nearest_insert ));
					node->city = minJ;
					node->next = NULL;
					current->next = node;
					current = current->next;
			}
			else
			{
				p1 = first->next;
				while (p1->city != minI)
					p1=p1->next;
				tmp = p1->next;
				node = (struct nearest_insert *)malloc(sizeof(struct nearest_insert ));
				node->city = minJ;
				node->next = tmp;
				p1->next = node;
			}
		}
		else
		{//more than 3 nodes
			p1 = first;
			min_i = p1->city;
			min_j = p1->next->city;
			min_diff = distD(min_i,minJ,posx,posy) + distD(minJ,min_j,posx,posy) - distD(min_i,min_j,posx,posy);
			p1 = p1->next;
			while(p1->next!=NULL)
			{//go through the path
				i = p1->city;
				j = p1->next->city;
				//check two opt
				diff = distD(i,minJ,posx,posy) + distD(minJ,j,posx,posy) - distD(i,j,posx,posy);
				if(min_diff > diff )
				{
					min_diff = diff;
					min_i = i;
					min_j = j;
				}
				p1 = p1->next;	
			}
			i = p1->city;
			j = 0;
			diff = distD(i,minJ,posx,posy) + distD(minJ,j,posx,posy) - distD(i,j,posx,posy);
			//and cycle around
			if(min_diff > diff )
			{
				min_diff = diff;
				min_i = i;
				min_j = j;
			}

			if(current->city == min_i)
			{
				node = (struct nearest_insert *)malloc(sizeof(struct nearest_insert ));
				node->city = minJ;
				node->next = NULL;
				current->next = node;
				current = current->next;
			}
			else
			{
				p1 = first;
				while (p1->city != min_i)
				{	p1=p1->next;}
				tmp = p1->next;
				node = (struct nearest_insert *)malloc(sizeof(struct nearest_insert ));
				node->city = minJ;
				node->next = tmp;
				p1->next = node;
			}
		}
		count++;
	}
	i=0;
	p1=first;
	while(p1!=NULL)
	{
		r[i] = p1->city;
		p1=p1->next;
		i++;
	}
}

struct greedy
{
	int city;
	struct greedy *next;
};
/* Initial solution construction using greedy approach */
void greedy(int *r, float *posx, float *posy, long cities)
{
	struct greedy *node,*p1,*current,*first = NULL;

	int i,j,min=0,dist;
	int count,minI,minJ; 
	int *v;

	v = (int *)calloc(cities, sizeof(int));
	node = (struct greedy *)malloc(sizeof(struct greedy ));

	node->city = 0;
	node->next = NULL;
	first = node;
	current = node;

	count = 1;
	v[0]=1;
	min = 0;

	while(count != cities)
	{	//operate from the first city,
		i = first->city;
		min = 0;
		//keep exploring cities
		for(j = 0; j < cities; j++)
		{	//until you find a new one
			if(!v[j] && i != j)
			{	//calc distance and store min dist
				dist = distD(i,j,posx,posy);
				if(min==0)
				{
					min=dist;
					minI=i;
					minJ=j;

				}
				if(min>dist)
				{
					min=dist;
					minI=i;
					minJ=j;
				}
			}
		}
		//if this is not the first pass
		if(first != current)
		{
			i = current->city;
			for(j = 0; j < cities; j++)
			{//then store into list. basically the same because we needed cases
				if(!v[j] && i != j)
				{
					dist = distD(i,j,posx,posy);
					if(min>dist)
					{
						min=dist;
						minI=i;
						minJ=j;
					}
				}
			}
		}
		v[minJ]=1;
		
		if(first->city == minI)
		{
			if(first->next == NULL)
			{
				node = (struct greedy *)malloc(sizeof(struct greedy ));
				node->city = minJ;
				node->next = NULL;
				first->next = node;
				current = current->next;
			}
			else
			{
				node = (struct greedy *)malloc(sizeof(struct greedy ));
				node->city = minJ;
				node->next = first;
				first = node;
			}
		}
		else
		{
			if (current->city == minI)
			{
				node = (struct greedy *)malloc(sizeof(struct greedy ));
				node->city = minJ;
				node->next = NULL;
				current->next = node;
				current = current->next;
			}
		}
	count++;
	}

	i=0;
	p1=first;
	while(p1!=NULL)
	{
		r[i] = p1->city;
		p1=p1->next;
		i++;
	}

}
struct visit_list
{
	int city;
	struct visit_list *next;
};
struct MST
{
	int i,j,weight;
	struct MST *next;
	struct MST *prev;
};
struct eul_tour
{
	int city;
	struct eul_tour *next;	
	struct eul_tour *prev;	
};
/* Initial solution construction using MST approach */
//minimum spanning tree
void mst_init(int *r, float *posx, float *posy, long cities)
{
	int *deg,*var_deg,dist;
	int i,j, min,min_i,min_j, count,*v;

	struct eul_tour *et,*top=NULL,*curr, *node1,*rev;
	struct visit_list *first=NULL,*current, *p1,*visited;
	struct MST *head =NULL, *cur, *node,*p;

	deg = (int*)calloc(cities,sizeof(int) );
	v = (int*) calloc(cities, sizeof(int));
	visited = (struct visit_list*)malloc(sizeof(struct visit_list));

	visited->city = 0;
	visited->next = NULL;
	first = visited;
	current = first;
	count = 1;
	p1 =first;
	v[0] = 1;
	while(count != cities )
	{	//while all cities aren't explored
		min = 0;
	
		for(p1 = first; p1!=NULL; p1=p1->next)
		{	
			//fix a node,
			i = p1->city;
			for(j = 0; j < cities; j++)
			{
				//check and find the smallest edge with that node
				if(i != j && !v[j])
				{
					dist = distD(i,j,posx,posy);
					if(min == 0 )
					{
						min = dist;
						min_i =i;
						min_j =j;

					}
					if(min > dist)
					{
						min = dist;
						min_i =i;
						min_j =j;
					}
				}
		
			}
		
		}
		v[min_j] =1;
		visited = (struct visit_list*)malloc(sizeof(struct visit_list));
		visited->city = min_j;
		visited->next = NULL;
		current->next =visited;
		current = current->next;
		//and now add that edge
		deg[min_i]+=1;
		deg[min_j]+=1;
		//make a node of the mst,
		//and add that edge
		node = (struct MST*)malloc(sizeof(struct MST));
		node->i = min_i;
		node->j = min_j;
		node->weight = min;
		node->next = NULL;
		//linked list stuff
		if(head == NULL)
		{
			node->prev = NULL;
			head = node;
			cur = node;
		}	
		else
		{
			node->prev = cur;
			cur->next = node;
			cur = cur->next;
		}
	count++; 
	}

	v = (int*) calloc(cities, sizeof(int));
	var_deg = (int*) calloc(cities, sizeof(int));
	p = head;
	//find a leaf,
	while(deg[p->i] != 1 && deg[p->j] != 1)
		p = p->next;
	//take the leaf city, 
	if(deg[p->i] == 1 )
	{	//take the leaf,make it a node in the euler tour, make the jth node the other node of the edge in the tour,
		i = p->i;
		node1 = (struct eul_tour*)malloc(sizeof(struct eul_tour));
		node1->city = i;
		node1->next = NULL;
		node1->prev = NULL;
		top = node1;
		curr = node1;
		v[i] = 1;
		var_deg[i]++;
		node1 = (struct eul_tour*)malloc(sizeof(struct eul_tour));
		node1->city = p->j;
		node1->next = NULL;
		node1->prev = curr;
		curr->next = node1;
		curr = curr->next;
		j = p->j;
		v[j] = 1;	
		var_deg[j]++;
	}
	else
	{
		i = p->j;
		node1 = (struct eul_tour*)malloc(sizeof(struct eul_tour));
		node1->city = i;
		node1->next = NULL;
		node1->prev = NULL;
		top = node1;
		curr = node1;
		v[i] = 1;
		var_deg[i]++;

		node1 = (struct eul_tour*)malloc(sizeof(struct eul_tour));
		node1->city = p->i;
		node1->next = NULL;
		node1->prev = curr;
		curr->next = node1;
		curr = curr->next;
		j = p->i;
		v[j] = 1;	
		var_deg[j]++;
	}
	//now we have 2 nodes, ie one edge,
	count = 2;
	p = head;
	while(count != cities)
	{
		if(deg[j]!= 1)
		{
			if(p->i == j && !v[p->j])
			{
				node1 = (struct eul_tour*)malloc(sizeof(struct eul_tour));
				node1->city = p->j;
				node1->next = NULL;
				node1->prev = curr;
				curr->next = node1;
				curr = curr->next;
				j = p->j;
				v[j] = 1;
				var_deg[p->i]++;	
				var_deg[p->j]++;	
				count++;
				p = p->next;
			}
			else if(p->j == j && !v[p->i])
			{
				node1 = (struct eul_tour*)malloc(sizeof(struct eul_tour));
				node1->city = p->i;
				node1->next = NULL;
				node1->prev = curr;
				curr->next = node1;
				curr = curr->next;
				j = p->i;
				v[j] = 1;	
				var_deg[p->i]++;	
				var_deg[p->j]++;	
				count++;
				p = p->next;
			}
			else
			{
				p = head;
				while( (p->i != j || v[p->j]) && (p->j != j || v[p->i]) )
					p = p->next;
			}
		}
		else
		{
			rev = curr->prev;
			while(deg[rev->city] == var_deg[rev->city])
			{
				rev = rev ->prev;			
			}
			
			j = rev->city;
			p = head;
		}	 
	}

	v = (int*) calloc(cities, sizeof(int));
	i=0;
	et = top;
	while(et != NULL)
	{
		if(v[et->city] == 0)
		{
			r[i++] = et->city; 		
			v[et->city] = 1;		
		}
		et = et->next;	
	}

}
//if the edge exists, then return 1
int searchEdge(int min_i,int min_j, struct MST * p)
{
	int flag =0;
		while(p != NULL )
		{
			if( (p->i == min_i && p->j == min_j) || (p->i == min_j && p->j == min_i ) )
			{
				flag = 1;
				break; 
			}
			p = p->next;	
		}
	if(flag == 1 )
		return 1;
	else
		return 0;

}

/* Initial solution construction using Christofides' approach */
void christofide_init(int *r, float *posx, float *posy, long cities)
{
	int *deg,*var_deg,dist,flg=0;
	int i,j, min,min_i,min_j, count,*v,size;
	int *odd_array,flag = 0;
	FILE *fp; char line[100];

	struct eul_tour *et,*top=NULL,*curr, *node1,*rev;
	struct visit_list *first=NULL,*current, *p1,*visited;
	struct MST *head =NULL, *cur, *node,*p;
	struct odd_degree *init=NULL, *at, *odd;
	struct rev_visit* rev_node=NULL,*loop;

	deg = (int*)calloc(cities,sizeof(int));
	v = (int*) calloc(cities, sizeof(int));
	visited = (struct visit_list*)malloc(sizeof(struct visit_list));

	visited->city = 0;
	visited->next = NULL;
	first = visited;
	current = first;
	count = 1;
	p1 =first;
	v[0] = 1;

	while(count != cities )
	{	
		min = 0;
	
		for(p1 = first; p1!=NULL; p1=p1->next)
		{	

			i = p1->city;
			for(j = 0; j < cities; j++)
			{
				if(i != j && !v[j])
				{
					dist = distD(i,j,posx,posy);
					if(min == 0 )
					{
						min = dist;
						min_i =i;
						min_j =j;

					}
					if(min > dist)
					{
						min = dist;
						min_i =i;
						min_j =j;
					}
				}
		
			}

		}
		v[min_j] =1;
		visited = (struct visit_list*)malloc(sizeof(struct visit_list));
		visited->city = min_j;
		visited->next = NULL;
		current->next =visited;
		current = current->next;
	
		deg[min_i]+=1;
		deg[min_j]+=1;

		node = (struct MST*)malloc(sizeof(struct MST));
		node->i = min_i;
		node->j = min_j;
		node->weight = min;
		node->next = NULL;

		if(head == NULL)
		{
			node->prev = NULL;
			head = node;
			cur = node;
		}	
		else
		{
			node->prev = cur;
			cur->next = node;
			cur = cur->next;
		}
	count++; 
	}
	p = head;
	size = 0;
	//make set of all odd degree nodes,
	for(i = 0; i < cities; i++)
	{
		if(deg[i]%2 != 0)
		{
	
			odd = (struct odd_degree*)malloc(sizeof(struct odd_degree));
			odd->city = i;
			odd->next = NULL;
			if(init == NULL)
			{
				init = odd;
				at = odd;
			}
			else
			{
				at->next = odd;
				at = at->next;

			}
		size++;
		}
	}
	
	odd_array = (int*)malloc(sizeof(int)*size);
	odd = init;
	i = 0;

	while(odd != NULL)
	{
		odd_array[i++] = odd->city;
		odd = odd->next;
	}
	//odd_array has all nodes with odd degrees
	v = (int*) calloc(size, sizeof(int));
	assert(size % 2 == 0);
	fp = fopen("odd_edges.txt", "w");
	//foul play case
	assert(size >= 2);
	fprintf(fp, "%d %d\n", size, (size*(size-1))/2);
	for (i = 0; i < size; i++) 
	{
		for (j = i+1; j < size; j++) 
		{
		fprintf(fp, "%d %d %ld\n", i, j, distD(odd_array[i],odd_array[j],posx,posy));
		}
	}
	fclose(fp);
	if(system("/home/sparklab/pramod/blossom5-v2.05.src/blossom5 -e odd_edges.txt -w min_edges.txt") != 0) 
	{
		printf("\nError: please install blossom5 matching code\n");
		exit(-1);
	}

	fp = fopen("min_edges.txt", "r");
	fgets(line, sizeof(line), fp); 
	for (i = 0; i < size/2; i++) 
	{
		assert(fgets(line, sizeof(line), fp) != NULL); 
		assert(sscanf(line, "%d %d", &i, &j) == 2); 
		if(searchEdge(odd_array[i],odd_array[j],head) ==  0)
		{
			deg[odd_array[i]]+=1;
			deg[odd_array[j]]+=1;

			node = (struct MST*)malloc(sizeof(struct MST));
			node->i = odd_array[i];
			node->j = odd_array[j];
			node->weight = distD(odd_array[i],odd_array[j], posx, posy);
			node->next = NULL;
			node->prev = cur;
			cur->next = node;
			cur = cur->next;
		}
	}
	fclose(fp); 

	v = (int*) calloc(cities, sizeof(int));
	var_deg = (int*) calloc(cities, sizeof(int));
	p = head;
	while(p != NULL)
	{
		if(deg[p->i] != 1 && deg[p->j] != 1)
		{	
			p = p->next;
		}
		else
		{
			flag = 1;
			break;		
		}
		
	}
	if(flag == 1)
	{
		if(deg[p->i] == 1 )
		{	i = p->i;
			node1 = (struct eul_tour*)malloc(sizeof(struct eul_tour));
			node1->city = i;
			node1->next = NULL;
			node1->prev = NULL;
			top = node1;
			curr = node1;
			v[i] = 1;
			var_deg[i]++;

			node1 = (struct eul_tour*)malloc(sizeof(struct eul_tour));
			node1->city = p->j;
			node1->next = NULL;
			node1->prev = curr;
			curr->next = node1;
			curr = curr->next;

			j = p->j;
			v[j] = 1;	
			var_deg[j]++;
		}
		else
		{
			i = p->j;
			node1 = (struct eul_tour*)malloc(sizeof(struct eul_tour));
			node1->city = i;
			node1->next = NULL;
			node1->prev = NULL;
			top = node1;
			curr = node1;
			v[i] = 1;
			var_deg[i]++;

			node1 = (struct eul_tour*)malloc(sizeof(struct eul_tour));
			node1->city = p->i;
			node1->next = NULL;
			node1->prev = curr;
			curr->next = node1;
			curr = curr->next;

			j = p->i;
			v[j] = 1;	
			var_deg[j]++;
		}
		count = 2;
		p = head;
		while(count != cities)
		{
			if(deg[j]!= 1)
			{
				if(p->i == j && !v[p->j])
				{
					node1 = (struct eul_tour*)malloc(sizeof(struct eul_tour));
					node1->city = p->j;
					node1->next = NULL;
					node1->prev = curr;
					curr->next = node1;
					curr = curr->next;
					
					var_deg[p->i]++;	
					var_deg[p->j]++;	
					count++;
					
					j = p->j;
					v[j] = 1;
					p = p->next;
					if(p == NULL)
						p = head;
					
				}
				else if(p->j == j && !v[p->i])
				{
					node1 = (struct eul_tour*)malloc(sizeof(struct eul_tour));
					node1->city = p->i;
					node1->next = NULL;
					node1->prev = curr;
					curr->next = node1;
					curr = curr->next;

					var_deg[p->i]++;	
					var_deg[p->j]++;	
					count++;
			
					j = p->i;
					v[j] = 1;	
					p = p->next;
					if(p == NULL)
						p = head;
					

				}
				else
				{
					p = head;
					while(p != NULL)
					{
						if( (p->i != j || v[p->j]) && (p->j != j || v[p->i]) )
						{
							p = p->next;

						}
						else
						{
							flg = 1;
							break;
						}
					}
					if(flg == 0)
					{
						var_deg[j]++;
						et = curr-> prev;
						if(rev_node == NULL)
						{
							loop = (struct rev_visit *)malloc(sizeof(struct rev_visit));
							loop->i = j;
							while(deg[et->city] == var_deg[et->city] || et->city == j)
							{
								et = et-> prev;
							}
							j = et->city;
							loop->j = j;
							rev_node = loop;
							p = head;
						}
						else
						{
							if(j == rev_node->i || j == rev_node->j)
							{
								i = j == rev_node->i ? rev_node->j :rev_node->i;
								while(deg[et->city]==var_deg[et->city]|| et->city == j || et->city == i)
								{
									et = et-> prev;
								}
							}
							else
							{
								while(deg[et->city] == var_deg[et->city] || et->city == j)
								{
									et = et-> prev;
								}
							}
							rev_node->i = j;
							j = et->city;
							rev_node->j = j;
							p = head;
						}
						
					}
					
					flg = 0;	
				}
			}
			else
			{
				rev = curr->prev;
				while(deg[rev->city] == var_deg[rev->city] || rev->city == j)
				{
					rev = rev ->prev;			
				}
				j = rev->city;
				p = head;
			}	 
		}

		v = (int*) calloc(cities, sizeof(int));
		i=0;
		et = top;
		while(et != NULL)
		{
			if(v[et->city] == 0)
			{
				r[i++] = et->city; 		
				v[et->city] = 1;		
			}
			et = et->next;	
		}
	}
	else
	{
		v = (int*) calloc(cities, sizeof(int));
		p = head;
		i = 0;
		while(i != cities )
		{
			if(v[p->i] == 0)
			{
				r[i++] = p->i; 		
				v[p->i] = 1;		
			}
			if(v[p->j] == 0)
			{
				r[i++] = p->j; 		
				v[p->j] = 1;		
			}
			
			p = p->next;	
		}
	}
}

/* Initial solution construction using Clarke-Wright approach */
struct init_route
{
	int city;
	struct init_route *next;
};
struct clarke_wright
{
	int i,j, save;
	struct clarke_wright *next;
};

void clarke_wright_init(int *r, float *posx, float *posy, long cities, long no_pairs)
{
	int i,j,cnt;
	int *v;

	struct clarke_wright *cw,*cur,*cw1,*cw2;
	struct clarke_wright *top = NULL;

	for(i=1; i<cities-1; i++)
		for(j=i+1; j<cities; j++)
		{
			cw = (struct clarke_wright*)malloc(sizeof(struct clarke_wright) );
			cw->save = distD(0,i,posx,posy) + distD(0,j,posx,posy) - distD(i,j,posx,posy);
			cw->i = i;
			cw->j = j;		
			if(top==NULL)
			{
				cw->next= NULL;
				top = cw;			
				cur = cw;
			}
			else if( cw->save > top->save)
			{
			
				cw->next = top;
				top = cw;
			}
			else if (cw->save > cur->save && cw->save < top->save && cur != top)
			{
				cw1 = top;
				cw2 = top->next;
				while(cw2->save > cw->save)
				{
					cw2 = cw2->next;
					cw1 = cw1->next;

				}
				cw->next = cw2;
				cw1->next = cw;

			}
			else
			{
				cw->next = NULL;
				cur->next =cw;
				cur = cur->next;
			}
			
		}
	i = 0; 
	r[i++] = 0;	
	v=(int*)calloc(cities,sizeof(int));
	v[0] = 1;
	cw = top;
	r[i++] = cw->i;	
	v[cw->i] = 1;

	r[i++] = cw->j;	
	v[cw->j] = 1;
	cnt = 3;
	cw = cw->next;
	while(cnt != cities)
	{
		if( !v[cw->i] && !v[cw->j] )
		{
			r[i++] = cw->i;	
			v[cw->i] = 1;

			r[i++] = cw->j;	
			v[cw->j] = 1;
			cnt+=2;
		}
		else if( !v[cw->i]  )
		{
			r[i++] = cw->i;	
			v[cw->i] = 1;
			cnt++;
		}
		else if( !v[cw->j]  )
		{
			r[i++] = cw->j;	
			v[cw->j] = 1;
			cnt++;

		}
		cw = cw->next;

	}
}
void routeChecker(long N,int *r)
{
	int *v,i,flag=0;
	v=(int*)calloc(N,sizeof(int));	

	for(i=0;i<N;i++)
		v[r[i]]++;
	for(i=0;i<N;i++)
	{
		if(v[i] != 1 )
		{
			flag=1;
			printf("breaking at %d",i);
			break;
		}
	}
	if(flag==1)
		printf("\nroute is not valid");
	else
		printf("\nroute is valid");
}
/*Distance calculation of the initial solution */
long distH(float *px,float *py,long cit)
{
	float dx,dy;
	long cost=0;
	int i;
	for(i=0;i<(cit-1);i++)
	{
		dx=px[i]-px[i+1];
		dy=py[i]-py[i+1]; 
		cost+=sqrtf( (dx*dx) + (dy*dy) );
	}
	dx=px[i]-px[0];
	dy=py[i]-py[0]; 
	cost+=sqrtf( (dx*dx) + (dy*dy) );
	return cost;

}

int main(int argc, char *argv[])
{
	
	float *posx, *posy;
	float *px, *py,tm;
	char str[256];  
	float *d_posx, *d_posy;
	long x,y;
	int blk,thrd;
	clock_t start,end,start1,end1;
	long sol,tid,cities,no_pairs,dst,d;
	int *route,count=0;
	int ch, cnt, in1;
	float in2, in3;
        unsigned long long *d_dst_tid;
	FILE *f;

	f = fopen(argv[1], "r");
	if (f == NULL) {fprintf(stderr, "could not open file \n");  exit(-1);}

	ch = getc(f);  while ((ch != EOF) && (ch != '\n')) ch = getc(f);
	ch = getc(f);  while ((ch != EOF) && (ch != '\n')) ch = getc(f);
	ch = getc(f);  while ((ch != EOF) && (ch != '\n')) ch = getc(f);

	ch = getc(f);  while ((ch != EOF) && (ch != ':')) ch = getc(f);
	fscanf(f, "%s\n", str);
	cities = atoi(str);
	if (cities <= 2) {fprintf(stderr, "only %d cities\n", cities);  exit(-1);}

	posx = (float *)malloc(sizeof(float) * cities);  if (posx == NULL) {fprintf(stderr, "cannot allocate posx\n");  exit(-1);}
	posy = (float *)malloc(sizeof(float) * cities);  if (posy == NULL) {fprintf(stderr, "cannot allocate posy\n");  exit(-1);}
	px = (float *)malloc(sizeof(float) * cities);  if (px == NULL) {fprintf(stderr, "cannot allocate posx\n");  exit(-1);}
	py = (float *)malloc(sizeof(float) * cities);  if (py == NULL) {fprintf(stderr, "cannot allocate posy\n");  exit(-1);}
	route = (int *)malloc(sizeof(int) * cities);  if (route == NULL) {fprintf(stderr, "cannot allocate route\n");  exit(-1);}
	
	ch = getc(f);  while ((ch != EOF) && (ch != '\n')) ch = getc(f);
	fscanf(f, "%s\n", str);
	if (strcmp(str, "NODE_COORD_SECTION") != 0) {fprintf(stderr, "wrong file format\n");  exit(-1);}

	cnt = 0;

	while (fscanf(f, "%d %f %f\n", &in1, &in2, &in3)) 
	{
		posx[cnt] = in2;
		posy[cnt] = in3;
		cnt++;
		if (cnt > cities) {fprintf(stderr, "input too long\n");  exit(-1);}
		if (cnt != in1) {fprintf(stderr, "input line mismatch: expected %d instead of %d\n", cnt, in1);  exit(-1);}
	}

	if (cnt != cities) {fprintf(stderr, "read %d instead of %d cities\n", cnt, cities);  exit(-1);}
	fscanf(f, "%s", str);
	if (strcmp(str, "EOF") != 0) {fprintf(stderr, "didn't see 'EOF' at end of file\n");  exit(-1);}
    	fflush(f);
	fclose(f);

	sol=cities*(cities-1)/2;
	int intl;	
	printf("\nChoose an initial solution setup approach\n1.Sequenced\n2.Random\n3.NN\n4.NI\n5.Greedy\n6.MST\n7.Christofide\n8.Clarke-Wright\n");
	scanf("%d",&intl);
	start = clock();
	switch(intl)
	{
		case 1:
			seq_init(route,cities);  
			routeChecker(cities, route);
			setCoord(route,posx,posy,px,py,cities);
			dst=distH(px,py,cities);
			break;

		case 2:
			random_init(route,cities); 
			routeChecker(cities, route);
			setCoord(route,posx,posy,px,py,cities); 
			dst=distH(px,py,cities);
			break;
		case 3:
			dst = nn_init(route,cities,posx,posy);
			routeChecker(cities, route);
			setCoord(route,posx,posy,px,py,cities);
			break;
		case 4:
			nearest_insertion(route,posx,posy,cities);
			routeChecker(cities, route);
			setCoord(route,posx,posy,px,py,cities);
			dst=distH(px,py,cities);
			break;
		case 5:
			greedy(route,posx,posy,cities);
			routeChecker(cities, route);
			setCoord(route,posx,posy,px,py,cities);
			dst=distH(px,py,cities);
			break;
		case 6:
			mst_init(route,posx,posy,cities);
			routeChecker(cities, route);
			setCoord(route,posx,posy,px,py,cities);
			dst=distH(px,py,cities);
			break;
		case 7:
			christofide_init(route, posx, posy, cities);
			routeChecker(cities, route);
			setCoord(route,posx,posy,px,py,cities);
			dst=distH(px,py,cities);
			break;
		case 8:
			no_pairs = (cities-1)*(cities-2)/2;
			clarke_wright_init(route, posx, posy, cities, no_pairs);
			routeChecker(cities, route);
			setCoord(route,posx,posy,px,py,cities);
			dst=distH(px,py,cities);
			break;

	}
	end = clock();
	tm = ((double) (end - start)) / CLOCKS_PER_SEC;
	printf("\ninitial cost : %ld time : %f\n",dst,tm);

	start1 = clock();
	count = 1;
	unsigned long long dst_tid = (((long)dst+1) << 32) -1;
        unsigned long long dtid;
	long itr=floor(cities/2);
	int nx, ny;
	if(cities <= 32)
	{
		blk = 1 ;
		nx = cities;
		ny = cities;
	}
	else
	{
		blk = (cities - 1) / 32 + 1;
		nx = 32;
		ny = 32;
	}
	dim3 thrds (nx,ny);
	dim3 blks (blk,blk);
	if(cudaSuccess!=cudaMalloc((void**)&d_posx,sizeof(float)*cities))
	printf("\nCan't allocate memory for coordinate x on GPU");
	if(cudaSuccess!=cudaMalloc((void**)&d_posy,sizeof(float)*cities))
	printf("\nCan't allocate memory for coordinate y on GPU");
	if(cudaSuccess!=cudaMalloc((void**)&d_dst_tid,sizeof(unsigned long long)))
	printf("\nCan't allocate memory for dst_tid on GPU");
    	if(cudaSuccess!=cudaMemcpy(d_dst_tid,&dst_tid,sizeof(unsigned long long),cudaMemcpyHostToDevice))
	printf("\nCan't transfer dst_tid on GPU");
	if(cudaSuccess!=cudaMemcpy(d_posx,px,sizeof(float)*cities,cudaMemcpyHostToDevice))
	printf("\nCan't transfer px on GPU");
	if(cudaSuccess!=cudaMemcpy(d_posy,py,sizeof(float)*cities,cudaMemcpyHostToDevice))
	printf("\nCan't transfer py on GPU");

	int strat;	
	printf("\n Choose a CUDA thread mapping strategy\n1.TPR\n2.TPRED\n3.TPRC\n4.TPN\n");
	scanf("%d",&strat);
	switch(strat)
	{
		case 1:

			if(cities<=1024)
			{
				blk=1;
				thrd=cities;
			}
			else
			{
				blk=(cities-1)/1024+1;
				thrd=1024;
			}
			
			tsp_tpr<<<blk,thrd>>>(d_posx,d_posy,dst,d_dst_tid,cities);
			
			if(cudaSuccess!=cudaMemcpy(&dtid,d_dst_tid,sizeof(unsigned long long),cudaMemcpyDeviceToHost))
			printf("\nCan't transfer minimal cost back to CPU");

			d = dtid >> 32;
			
			while( d < dst )
			{
				dst=d;
				tid = dtid & ((1ull<<32)-1); 
				x=cities-2-floor((sqrt(8*(sol-tid-1)+1)-1)/2);
				y=tid-x*(cities-1)+(x*(x+1)/2)+1;
				twoOpt(x,y,px,py);
				if(cudaSuccess!=cudaMemcpy(d_posx,px,sizeof(float)*cities,cudaMemcpyHostToDevice))
				printf("\nCan't transfer px on GPU");
				if(cudaSuccess!=cudaMemcpy(d_posy,py,sizeof(float)*cities,cudaMemcpyHostToDevice))
				printf("\nCan't transfer py on GPU");
				unsigned long long dst_tid = (((long)dst+1) << 32) -1;
				if(cudaSuccess!=cudaMemcpy(d_dst_tid,&dst_tid,sizeof(unsigned long long),cudaMemcpyHostToDevice))
				printf("\nCan't transfer dst_tid on GPU");

				tsp_tpr<<<blk,thrd>>>(d_posx,d_posy,dst,d_dst_tid,cities);
				if(cudaSuccess!=cudaMemcpy(&dtid,d_dst_tid,sizeof(unsigned long long),cudaMemcpyDeviceToHost))
				printf("\nCan't transfer minimal cost back to CPU");
			  	d = dtid >> 32;
				count++;
			}
		break;
		case 2:
			
			if(cities<1024)
			{
				blk=1;
				thrd=cities;
			}
			else
			{
				blk=(cities-1)/1024+1;
				thrd=1024;
			}	

			tsp_tpred<<<blk,thrd>>>(d_posx,d_posy,dst,d_dst_tid,cities,itr);
			
			if(cudaSuccess!=cudaMemcpy(&dtid,d_dst_tid,sizeof(unsigned long long),cudaMemcpyDeviceToHost))
			printf("\nCan't transfer minimal cost back to CPU");

			d = dtid >> 32;
			
			while( d < dst )
			{

				dst=d;
				tid = dtid & ((1ull<<32)-1); 
				x=cities-2-floor((sqrt(8*(sol-tid-1)+1)-1)/2);
				y=tid-x*(cities-1)+(x*(x+1)/2)+1;
				twoOpt(x,y,px,py);
				if(cudaSuccess!=cudaMemcpy(d_posx,px,sizeof(float)*cities,cudaMemcpyHostToDevice))
				printf("\nCan't transfer px on GPU");
				if(cudaSuccess!=cudaMemcpy(d_posy,py,sizeof(float)*cities,cudaMemcpyHostToDevice))
				printf("\nCan't transfer py on GPU");
				unsigned long long dst_tid = (((long)dst+1) << 32) -1;
				if(cudaSuccess!=cudaMemcpy(d_dst_tid,&dst_tid,sizeof(unsigned long long),cudaMemcpyHostToDevice))
				printf("\nCan't transfer dst_tid on GPU");

				tsp_tpred<<<blk,thrd>>>(d_posx,d_posy,dst,d_dst_tid,cities,itr);
				
				if(cudaSuccess!=cudaMemcpy(&dtid,d_dst_tid,sizeof(unsigned long long),cudaMemcpyDeviceToHost))
				printf("\nCan't transfer minimal cost back to CPU");
			  	d = dtid >> 32;
				count++;
			}
		break;
		case 3:
			
			tsp_tprc<<<blks,thrds>>>(d_posx,d_posy,dst,d_dst_tid,cities);
	
			if(cudaSuccess!=cudaMemcpy(&dtid,d_dst_tid,sizeof(unsigned long long),cudaMemcpyDeviceToHost))
			printf("\nCan't transfer minimal cost back to CPU");
		  	d = dtid >> 32;
			
			while( d < dst )
			{
				dst=d;
				tid = dtid & ((1ull<<32)-1); 
				x=cities-2-floor((sqrt(8*(sol-tid-1)+1)-1)/2);
				y=tid-x*(cities-1)+(x*(x+1)/2)+1;
				twoOpt(x,y,px,py);
				if(cudaSuccess!=cudaMemcpy(d_posx,px,sizeof(float)*cities,cudaMemcpyHostToDevice))
				printf("\nCan't transfer px on GPU");
				if(cudaSuccess!=cudaMemcpy(d_posy,py,sizeof(float)*cities,cudaMemcpyHostToDevice))
				printf("\nCan't transfer py on GPU");
				unsigned long long dst_tid = (((long)dst+1) << 32) -1;
				if(cudaSuccess!=cudaMemcpy(d_dst_tid,&dst_tid,sizeof(unsigned long long),cudaMemcpyHostToDevice))
				printf("\nCan't transfer dst_tid on GPU");

				tsp_tprc<<<blks,thrds>>>(d_posx,d_posy,dst,d_dst_tid,cities);
				if(cudaSuccess!=cudaMemcpy(&dtid,d_dst_tid,sizeof(unsigned long long),cudaMemcpyDeviceToHost))
				printf("\nCan't transfer minimal cost back to CPU");
			  	d = dtid >> 32;
				count++;
			}
		break;
		case 4:
			if(sol < 1024)
			{
				blk=1;
				thrd=sol;
			}
			else
			{
				blk=(sol-1)/1024+1;
				thrd=1024;
			}

			tsp_tpn<<<blk,thrd>>>(d_posx,d_posy,dst,d_dst_tid,cities,sol);

			if(cudaSuccess!=cudaMemcpy(&dtid,d_dst_tid,sizeof(unsigned long long),cudaMemcpyDeviceToHost))
			printf("\nCan't transfer minimal cost back to CPU");
			d = dtid >> 32;
			
			while( d < dst )
			{
				dst=d;
				tid = dtid & ((1ull<<32)-1); 
				x=cities-2-floor((sqrt(8*(sol-tid-1)+1)-1)/2);
				y=tid-x*(cities-1)+(x*(x+1)/2)+1;
				twoOpt(x,y,px,py);
				if(cudaSuccess!=cudaMemcpy(d_posx,px,sizeof(float)*cities,cudaMemcpyHostToDevice))
				printf("\nCan't transfer px on GPU");
				if(cudaSuccess!=cudaMemcpy(d_posy,py,sizeof(float)*cities,cudaMemcpyHostToDevice))
				printf("\nCan't transfer py on GPU");
				unsigned long long dst_tid = (((long)dst+1) << 32) -1;
				if(cudaSuccess!=cudaMemcpy(d_dst_tid,&dst_tid,sizeof(unsigned long long),cudaMemcpyHostToDevice))
				printf("\nCan't transfer dst_tid on GPU");

				tsp_tpn<<<blk,thrd>>>(d_posx,d_posy,dst,d_dst_tid,cities,sol);

				if(cudaSuccess!=cudaMemcpy(&dtid,d_dst_tid,sizeof(unsigned long long),cudaMemcpyDeviceToHost))
				printf("\nCan't transfer minimal cost back to CPU");
			  	d = dtid >> 32;
				count++;
			}
		break;
	}
	
	printf("\nMinimal Distance : %ld\n",d);

	printf("\nnumber of time climbed %d\n",count);
	end1 = clock();
	double t=((double) (end1 - start1)) / CLOCKS_PER_SEC;
	printf("\ntime : %f\n",t);
	cudaFree(d_posy);
	cudaFree(d_posx);
	cudaFree(d_dst_tid);
	free(posx);
	free(posy);
	free(px);
	free(py);
	free(route);
	return 0;
}

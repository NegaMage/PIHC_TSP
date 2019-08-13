#include"stdio.h"
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include"math.h"
#include <ctype.h>
#include <assert.h>

/* Euclidean distance calculation */
long distD(int i,int j,float *x,float*y)
{
	float dx=x[i]-x[j];
	float dy=y[i]-y[j]; 
	return(sqrtf( (dx*dx) + (dy*dy) ));
}

/* Initial solution construction using NN */
long nn_init(int *route,long cities,float *posx,float*posy)
{
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
		{
			if(i!=j && !visited[j])
			{
				min=distD(i,j,posx,posy);
				minj=j;
				break;	
			}
		}

		for(j=minj+1;j<cities;j++)
		{
			
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
	//minI is the index of I and J that are used to find minimum dist
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
	{	//as long as all cities haven't been explored
		min = 0;//minimum distance the thing will take
		for(route = first; route != NULL; route=route->next)
		{	//route is a linked list, and we're going through it
			i = route->city;
			for(j = 0; j < cities; j++)
			{	//for the other nodes,
				if(i !=j &&!v[j])
				{	//so long as you aren't exploring the same node from itself,
					// and you aren't rediscovering nodes,
					dist = distD(i,j,posx,posy);
					//find the distance it would take to add
					if(min==0)
					{//initialisation of min
						min=dist;
						minI=i;
						minJ=j;
	
					}
					if(min>dist)
					{//wait so the code is the same?
						min=dist;
						minI=i;
						minJ=j;
					}
				}
			}
		}
		//set J as explored
		v[minJ]=1;
		if(count < 3)
		{//now we have chosen at least 3 nodes. Otherwise, the graph has unique structure,
			//and it pays to check individual case
			if(first->city == minI)
			{	//if you just started exploring
				if(first->next == NULL)
				{	//make a new node, call it j
					node = (struct nearest_insert *)malloc(sizeof(struct nearest_insert ));
					node->city = minJ;
					node->next = NULL;
					first->next = node;
					current = current->next;
				}
				else
				{	//now inserting a new node to the end, between first and the next.
					tmp = first->next;
					node = (struct nearest_insert *)malloc(sizeof(struct nearest_insert ));
					node->city = minJ;
					node->next = tmp;
					first->next = node;
				}
			}
			else if(current->city == minI)
			{		//if the city you're exploring is back at i'th position.
					node = (struct nearest_insert *)malloc(sizeof(struct nearest_insert ));
					node->city = minJ;
					node->next = NULL;
					current->next = node;
					current = current->next;
			}
			else
			{	//If you're in the middle of a traversal
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
		else//you've had more than three nodes.
		{	
			p1 = first;//p1 is for traversal through the list
			min_i = p1->city;//so you have the city no. of the first node
			min_j = p1->next->city;//and of j
			min_diff = distD(min_i,minJ,posx,posy) + distD(minJ,min_j,posx,posy) - distD(min_i,min_j,posx,posy);
			p1 = p1->next;
			while(p1->next!=NULL)
			{	//check through all adjacent pairs, and find the min difference and replace as needed.
				i = p1->city;
				j = p1->next->city;
				diff = distD(i,minJ,posx,posy) + distD(minJ,j,posx,posy) - distD(i,j,posx,posy);
				if(min_diff > diff )
				{
					min_diff = diff;
					min_i = i;
					min_j = j;
				}
				p1 = p1->next;	
			}
			//checking the first and last cities, because the loop can't check this part.
			i = p1->city;
			j = 0;
			diff = distD(i,minJ,posx,posy) + distD(minJ,j,posx,posy) - distD(i,j,posx,posy);
			if(min_diff > diff )
			{
				min_diff = diff;
				min_i = i;
				min_j = j;
			}
			//if you're at the min_i position
			if(current->city == min_i)
			{	//then make a new node, and put it as the new minJ, and insert it to end of the list.
				//update current to this node.
				node = (struct nearest_insert *)malloc(sizeof(struct nearest_insert ));
				node->city = minJ;
				node->next = NULL;
				current->next = node;
				current = current->next;
			}
			else
			{	//then traverse to the min_i,
				p1 = first;
				while (p1->city != min_i)
				{	p1=p1->next;}
				tmp = p1->next;
				//find the min_i and push it to end of list.
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
	{	//store the path
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
{	//make some placement nodes
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
	{
		i = first->city;
		min = 0;
		for(j = 0; j < cities; j++)
		{//for all cities
			if(!v[j] && i != j)
			{//if the city hasn't been explored, and you aren't exploring yourself
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
		if(first != current)
		{
			i = current->city;
			for(j = 0; j < cities; j++)
			{
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
	{	//while you haven't explored all cities
		min = 0;
	
		for(p1 = first; p1!=NULL; p1=p1->next)
		{	//exploring the list so far,

			i = p1->city;
			for(j = 0; j < cities; j++)
			{	//for the other cities,
				
				if(i != j && !v[j])
				{	//if they haven't been explored yet,
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
		//setting least distance node as explored
		visited = (struct visit_list*)malloc(sizeof(struct visit_list));
		visited->city = min_j;
		visited->next = NULL;
		current->next =visited;
		current = current->next;
		//we are adding another edge between i and j, incrementing their degrees in the MST
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

	v = (int*) calloc(cities, sizeof(int));
	var_deg = (int*) calloc(cities, sizeof(int));
	p = head;
	//as long as you don't have some particular isolated edge,
	while(deg[p->i] != 1 && deg[p->j] != 1)
		p = p->next;
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
	v = (int*) calloc(size, sizeof(int));
	assert(size % 2 == 0);
	fp = fopen("odd_edges.txt", "w");
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
	if(system("/home/pramod/Downloads/blossom5-v2.05.src/blossom5 -e odd_edges.txt -w min_edges.txt") != 0) 
	//(system("/home/sparklab/pramod/blossom5-v2.05.src/blossom5 -e odd_edges.txt -w min_edges.txt") != 0) 
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

/* Arrange coordinate in initial solution's order*/
void setCoord(int *r,float *posx,float *posy,float *px,float *py,long cities)
{
	int i;
	for(i=0;i<cities;i++)
	{
		px[i]=posx[r[i]];
		py[i]=posy[r[i]];
	}
}

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
	int ch, cnt, in1;
	float in2, in3;
	FILE *f;
	float *posx, *posy;
	float *px, *py,tm;
	char str[256];  
	int *r;
	long dst,sol,d,cities,no_pairs,tid=0;
	int i,j,intl,count;
	
	clock_t start,end,start1,end1;

	f = fopen(argv[1], "r");
	if (f == NULL) {fprintf(stderr, "could not open file \n");  exit(-1);}

	ch = getc(f);  while ((ch != EOF) && (ch != '\n')) ch = getc(f);
	ch = getc(f);  while ((ch != EOF) && (ch != '\n')) ch = getc(f);
	ch = getc(f);  while ((ch != EOF) && (ch != '\n')) ch = getc(f);

	ch = getc(f);  while ((ch != EOF) && (ch != ':')) ch = getc(f);
	fscanf(f, "%s\n", str);
	cities = atoi(str);
	if (cities <= 2) {fprintf(stderr, "only %ld cities\n", cities);  exit(-1);}

	sol=cities*(cities-1)/2;
	posx = (float *)malloc(sizeof(float) * cities);  if (posx == NULL) {fprintf(stderr, "cannot allocate posx\n");  exit(-1);}
	posy = (float *)malloc(sizeof(float) * cities);  if (posy == NULL) {fprintf(stderr, "cannot allocate posy\n");  exit(-1);}
	px = (float *)malloc(sizeof(float) * cities);  if (px == NULL) {fprintf(stderr, "cannot allocate posx\n");  exit(-1);}
	py = (float *)malloc(sizeof(float) * cities);  if (py == NULL) {fprintf(stderr, "cannot allocate posy\n");  exit(-1);}
	
	r = (int *)malloc(sizeof(int) * cities);
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

	if (cnt != cities) {fprintf(stderr, "read %d instead of %ld cities\n", cnt, cities);  exit(-1);}
	fscanf(f, "%s", str);
	if (strcmp(str, "EOF") != 0) {fprintf(stderr, "didn't see 'EOF' at end of file\n");  exit(-1);}

	printf("\nChoose an initial solution setup approach\n1.Sequenced\n2.Random\n3.NN\n4.NI\n5.Greedy\n6.MST\n7.Christofide\n8.Clarke-Wright\n");
	scanf("%d",&intl);
	start = clock();
	switch(intl)
	{
		case 1:
			seq_init(r,cities);  
			routeChecker(cities, r);
			setCoord(r,posx,posy,px,py,cities);
			dst=distH(px,py,cities);
			break;

		case 2:
			random_init(r,cities); 
			routeChecker(cities, r);
			setCoord(r,posx,posy,px,py,cities); 
			dst=distH(px,py,cities);
			break;
		case 3:
			dst = nn_init(r,cities,posx,posy);
			routeChecker(cities, r);
			setCoord(r,posx,posy,px,py,cities);
			break;
		case 4:
			nearest_insertion(r,posx,posy,cities);
			routeChecker(cities, r);
			setCoord(r,posx,posy,px,py,cities);
			dst=distH(px,py,cities);
			break;
		case 5:
			greedy(r,posx,posy,cities);
			routeChecker(cities, r);
			setCoord(r,posx,posy,px,py,cities);
			dst=distH(px,py,cities);
			break;
		case 6:
			mst_init(r,posx,posy,cities);
			routeChecker(cities, r);
			setCoord(r,posx,posy,px,py,cities);
			dst=distH(px,py,cities);
			break;
		case 7:
			christofide_init(r, posx, posy, cities);
			routeChecker(cities, r);
			setCoord(r,posx,posy,px,py,cities);
			dst=distH(px,py,cities);
			break;
		case 8:
			no_pairs = (cities-1)*(cities-2)/2;
			clarke_wright_init(r, posx, posy, cities, no_pairs);
			routeChecker(cities, r);
			setCoord(r,posx,posy,px,py,cities);
			dst=distH(px,py,cities);
			break;

	}
	end = clock();
	tm = ((double) (end - start)) / CLOCKS_PER_SEC;
	printf("\ninitial cost : %ld time : %f\n",dst,tm);

	start1 = clock();
	float cost=0,dist=dst;
	float x=0,y=0;
	register int change=0;
	count=0;	
	/*Iterative hill approch */

	do{
		cost=0;
		dist=dst;
		for(i=0;i<(cities-1);i++)
		{	
	
			for(j = i+1; j < cities; j++)
			{
				cost = dist;			
				change = distD(i,j,px,py) 
				+ distD(i+1,(j+1)%cities,px,py) 
				- distD(i,(i+1)%cities,px,py)
				- distD(j,(j+1)%cities,px,py);
				cost += change;	
				if(cost < dst)
				{
					x = i;
					y = j;
					dst = cost;
				}
			}

		}
		if(dst<dist)
		{
			float *tmp_x,*tmp_y;
			tmp_x=(float*)malloc(sizeof(float)*(y-x));	
			tmp_y=(float*)malloc(sizeof(float)*(y-x));	
			for(j=0,i=y;i>x;i--,j++)
			{
				tmp_x[j]=px[i];
				tmp_y[j]=py[i];
			}
			for(j=0,i=x+1;i<=y;i++,j++)
			{
				px[i]=tmp_x[j];
				py[i]=tmp_y[j];
			}
			free(tmp_x);
			free(tmp_y);
		}
		count++;
	}while(dst<dist);

printf("\nMinimal distance found %ld\n",dst);
printf("\nnumber of time hill climbed %d\n",count);
end1 = clock();
printf("\ntime : %f\n",((double) (end1 - start1)) / CLOCKS_PER_SEC);

free(posx);
free(posy);
return 0;
}


package com.bookurtechnician.customer_app

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.ExperimentalAnimationApi
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.with
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.collectIsDraggedAsState
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowForward
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.google.accompanist.pager.*
import kotlinx.coroutines.delay
import kotlinx.coroutines.yield

/**
 * Data Model for Dynamic Promotional Banners
 */
data class HeroBannerItem(
    val bannerId: String,
    val imageUrl: String,
    val title: String,
    val subtitle: String,
    val badgeText: String = "POPULAR",
    val ctaText: String = "Book Now",
    val targetServiceId: String = "",
    val displayOrder: Int = 0,
    val active: Boolean = true
)

/**
 * Reusable Jetpack Compose Hero Banner Component
 *
 * Implements the layered architecture:
 * Box
 *  → Background Carousel Image (horizontal sliding)
 *  → Top Scrim Gradient (for location readability)
 *  → Bottom Scrim Gradient (for promotional content readability)
 *  → Location Overlay (Pinned top)
 *  → Search Bar Overlay (Directly under Location)
 *  → Promotional Content & CTA (Lower section)
 *  → Carousel Indicator Dots (Centered bottom)
 */
@OptIn(ExperimentalPagerApi::class, ExperimentalAnimationApi::class)
@Composable
fun HomeHeroBanner(
    modifier: Modifier = Modifier,
    banners: List<HeroBannerItem>,
    locationTitle: String = "Bellary Rd",
    locationSubtitle: String = "Vinayakanagar – Hebbal – Bengaluru...",
    onLocationClick: () -> Unit = {},
    onSearchBarClick: () -> Unit = {},
    onBannerCtaClick: (HeroBannerItem) -> Unit = {}
) {
    val bannerList = if (banners.isEmpty()) {
        listOf(
            HeroBannerItem(
                bannerId = "default",
                title = "Expert AC Service",
                subtitle = "Starting from ₹299",
                badgeText = "Trending",
                ctaText = "Book Now",
                imageUrl = "https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=1000",
                targetServiceId = "ac_clean"
            )
        )
    } else banners

    val pagerState = rememberPagerState(initialPage = 0)
    val isDragged by pagerState.interactionSource.collectIsDraggedAsState()

    // Auto-slide effect every 3.5 seconds when not interacting
    LaunchedEffect(isDragged, bannerList.size) {
        if (!isDragged && bannerList.size > 1) {
            while (true) {
                delay(3500)
                yield()
                val nextPage = (pagerState.currentPage + 1) % bannerList.size
                pagerState.animateScrollToPage(nextPage)
            }
        }
    }

    // Dynamic Rotating Search Suggestions
    val searchSuggestions = listOf(
        "Search for \"AC service\"",
        "Search for \"Electrician\"",
        "Search for \"Fan installation\"",
        "Search for \"Refrigerator service\"",
        "Search for \"Washing machine repair\""
    )
    var suggestionIndex by remember { mutableIntStateOf(0) }
    LaunchedEffect(Unit) {
        while (true) {
            delay(3000)
            suggestionIndex = (suggestionIndex + 1) % searchSuggestions.size
        }
    }

    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(330.dp)
            .clip(RoundedCornerShape(bottomStart = 28.dp, bottomEnd = 28.dp))
            .background(Color(0xFF0B1F63))
    ) {
        // 1. Hero Banner Carousel Background
        HorizontalPager(
            count = bannerList.size,
            state = pagerState,
            modifier = Modifier.fillMaxSize()
        ) { page ->
            val item = bannerList[page]
            AsyncImage(
                model = item.imageUrl,
                contentDescription = item.title,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize()
            )
        }

        // 2. Dual Scrim Gradients for text contrast
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(180.dp)
                .background(
                    Brush.verticalGradient(
                        colors = listOf(
                            Color.Black.copy(alpha = 0.65f),
                            Color.Black.copy(alpha = 0.20f),
                            Color.Transparent
                        )
                    )
                )
        )

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(180.dp)
                .align(Alignment.BottomCenter)
                .background(
                    Brush.verticalGradient(
                        colors = listOf(
                            Color.Transparent,
                            Color.Black.copy(alpha = 0.50f),
                            Color.Black.copy(alpha = 0.88f)
                        )
                    )
                )
        )

        // 3. Top Layer: Location Row + Search Bar
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .statusBarsPadding()
                .padding(horizontal = 16.dp, vertical = 8.dp)
                .align(Alignment.TopStart)
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onLocationClick() },
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Default.LocationOn,
                    contentDescription = "Location",
                    tint = Color.White,
                    modifier = Modifier.size(18.dp)
                )
                Spacer(modifier = Modifier.width(6.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = locationTitle,
                        color = Color.White,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        text = locationSubtitle,
                        color = Color.White.copy(alpha = 0.85f),
                        fontSize = 11.sp,
                        maxLines = 1,
                        overflow = TextOverflow.ellipsis
                    )
                }
                Icon(
                    imageVector = Icons.Default.KeyboardArrowDown,
                    contentDescription = "Dropdown",
                    tint = Color.White,
                    modifier = Modifier.size(20.dp)
                )
            }

            Spacer(modifier = Modifier.height(12.dp))

            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp)
                    .shadow(elevation = 8.dp, shape = RoundedCornerShape(16.dp))
                    .clickable { onSearchBarClick() },
                shape = RoundedCornerShape(16.dp),
                color = Color.White
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(horizontal = 16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.Search,
                        contentDescription = "Search",
                        tint = Color(0xFF64748B),
                        modifier = Modifier.size(20.dp)
                    )
                    Spacer(modifier = Modifier.width(10.dp))

                    AnimatedContent(
                        targetState = searchSuggestions[suggestionIndex],
                        transitionSpec = {
                            slideInVertically { height -> height } + fadeIn() with
                                    slideOutVertically { height -> -height } + fadeOut()
                        },
                        label = "search_suggestions"
                    ) { suggestion ->
                        Text(
                            text = suggestion,
                            color = Color(0xFF64748B),
                            fontSize = 13.5.sp,
                            fontWeight = FontWeight.Medium
                        )
                    }
                }
            }
        }

        // 4. Bottom Layer: Promotional Campaign Content & Indicators
        val currentBanner = bannerList[pagerState.currentPage % bannerList.size]
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.BottomStart)
                .padding(horizontal = 16.dp, vertical = 14.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Bottom
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Surface(
                        shape = RoundedCornerShape(4.dp),
                        color = Color(0xFFFFD700)
                    ) {
                        Text(
                            text = currentBanner.badgeText.uppercase(),
                            color = Color.Black,
                            fontSize = 9.sp,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp)
                        )
                    }

                    Spacer(modifier = Modifier.height(6.dp))

                    Text(
                        text = currentBanner.title,
                        color = Color.White,
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold,
                        maxLines = 2,
                        overflow = TextOverflow.ellipsis
                    )

                    Text(
                        text = currentBanner.subtitle,
                        color = Color.White.copy(alpha = 0.85f),
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Medium
                    )
                }

                Spacer(modifier = Modifier.width(12.dp))

                Button(
                    onClick = { onBannerCtaClick(currentBanner) },
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color.White,
                        contentColor = Color.Black
                    ),
                    shape = RoundedCornerShape(8.dp),
                    contentPadding = PaddingValues(horizontal = 14.dp, vertical = 8.dp),
                    elevation = ButtonDefaults.buttonElevation(defaultElevation = 2.dp)
                ) {
                    Text(
                        text = currentBanner.ctaText,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Icon(
                        imageVector = Icons.Default.ArrowForward,
                        contentDescription = "Arrow",
                        tint = Color.Black,
                        modifier = Modifier.size(12.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(14.dp))

            if (bannerList.size > 1) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.Center,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    repeat(bannerList.size) { index ->
                        val isSelected = pagerState.currentPage % bannerList.size == index
                        Box(
                            modifier = Modifier
                                .padding(horizontal = 3.dp)
                                .size(if (isSelected) 7.dp else 5.dp)
                                .clip(CircleShape)
                                .background(
                                    if (isSelected) Color.White else Color.White.copy(alpha = 0.4f)
                                )
                        )
                    }
                }
            }
        }
    }
}
